# Set or generate efficiency rates for every trophic link in the model.
#
# Efficiency rates are either given as-is by user
# or they are calculated from trophic links,
# and then they need their own parameters.

# (reassure JuliaLS)
(false) && (local Efficiency, _Efficiency)

# ==========================================================================================
# Blueprints.

module Efficiency_
include("blueprint_modules.jl")
include("blueprint_modules_identifiers.jl")
import .EN: Foodweb, _Foodweb

#-------------------------------------------------------------------------------------------
# From raw values.

mutable struct Raw <: Blueprint
    e::SparseMatrix{Float64}
    foodweb::Brought(Foodweb)
    Raw(e, foodweb = _Foodweb) = new(@tographdata(e, SparseMatrix{Float64}), foodweb)
end
F.implied_blueprint_for(bp::Raw, ::_Foodweb) = Foodweb(bp.e .!= 0)
@blueprint Raw "matrix"
export Raw

F.early_check(bp::Raw) = check_edges(bp.e, check)
check(e, ref = nothing) =
    check_value(e -> 0 <= e <= 1, e, ref, :e, "Not a value within [0, 1]")

function F.late_check(raw, bp::Raw)
    (; e) = bp
    A = @ref raw.trophic.matrix
    @check_template e A :trophic_links
end

F.expand!(raw, bp::Raw) = expand!(raw, bp.e)
expand!(raw, e) = raw.biorates.e = e

#-------------------------------------------------------------------------------------------
# From a scalar broadcasted to all trophic links.

mutable struct Flat <: Blueprint
    e::Float64
end
@blueprint Flat "homogeneous efficiency" depends(Foodweb)
export Flat

F.early_check(bp::Flat) = check(bp.e)
function F.expand!(raw, bp::Flat)
    (; e) = bp
    A = @ref raw.trophic.matrix
    e = to_template(e, A)
    expand!(raw, e)
end

#-------------------------------------------------------------------------------------------
# From a species-indexed adjacency list.

mutable struct Adjacency <: Blueprint
    e::@GraphData Adjacency{Float64}
    foodweb::Brought(Foodweb)
    Adjacency(e, foodweb = _Foodweb) = new(@tographdata(e, Adjacency{Float64}), foodweb)
end
F.implied_blueprint_for(bp::Adjacency, ::_Foodweb) = Foodweb(refs(bp.e))
@blueprint Adjacency "[predactor => [prey => efficiency]] adjacency list"
export Adjacency

F.early_check(bp::Adjacency) = check_edges(bp.e, check)
function F.late_check(raw, bp::Adjacency)
    (; e) = bp
    index = @ref raw.species.index
    A = @ref raw.trophic.matrix
    @check_list_refs e :trophic_link index template(A)
end

function F.expand!(raw, bp::Adjacency)
    index = @ref raw.species.index
    e = to_sparse_matrix(bp.e, index, index)
    expand!(raw, e)
end

#-------------------------------------------------------------------------------------------
# From herbivorous/carnivourous rates.
mutable struct Miele2019 <: Blueprint
    e_herbivorous::Float64
    e_carnivorous::Float64
    function Miele2019(; kwargs...)
        @kwargs_helpers kwargs
        eh = take_or!(:e_herbivorous, 0.45)
        ec = take_or!(:e_carnivorous, 0.85)
        no_unused_arguments()
        new(eh, ec)
    end
end
@blueprint Miele2019 "herbivorous/carnivorous efficiencies" depends(Foodweb)
export Miele2019

function F.early_check(bp::Miele2019)
    (; e_herbivorous, e_carnivorous) = bp
    check(e_herbivorous, (:herbivorous,))
    check(e_carnivorous, (:carnivorous,))
end

function F.expand!(raw, bp::Miele2019)
    hA = @ref raw.trophic.herbivory_matrix
    cA = @ref raw.trophic.carnivory_matrix
    eh = bp.e_herbivorous
    ec = bp.e_carnivorous
    e = eh * hA + ec * cA
    expand!(raw, e)
end

end

# ==========================================================================================
# Component and generic constructors.

@component Efficiency{Internal} requires(Foodweb) blueprints(Efficiency_)
export Efficiency

function (::_Efficiency)(e; kwargs...)

    e = @tographdata e {Symbol, SparseMatrix, Adjacency}{Float64}
    @check_if_symbol e (:Miele2019,)

    if e == :Miele2019
        Efficiency.Miele2019(; kwargs...)
    elseif e isa SparseMatrix
        Efficiency.Raw(e)
    elseif e isa Real
        Efficiency.Flat(e)
    else
        Efficiency.Adjacency(e)
    end

end

# Basic query.
@expose_data edges begin
    property(efficiency, e)
    depends(Efficiency)
    @species_index
    ref(raw -> raw.biorates.e)
    get(EfficiencyRates{Float64}, sparse, "trophic link")
    template(raw -> @ref raw.trophic.matrix)
    write!((raw, rhs::Real, i, j) -> begin
        Efficiency_.check(rhs, (i, j))
        Float64(rhs)
    end)
end

# Just display range.
function F.shortline(io::IO, model::Model, ::_Efficiency)
    nz = findnz(model._e)[3]
    print(io, "Efficiency: " * if isempty(nz)
        "·"
    else
        min, max = extrema(nz)
        min == max ? "$min" : "$min to $max"
    end)
end
