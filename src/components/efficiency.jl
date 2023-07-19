# Set or generate efficiency rates for every trophic link in the model.
#
# Efficiency rates are either given as-is by user
# or they are calculated from trophic links,
# and then they need their own parameters.
# Again, this leads to the definition
# of "two different blueprints for the same component".

# TODO: e is supposed to stand between 0 and 1.. but *should* we enforce that?

# ==========================================================================================

abstract type Efficiency <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input.
function Efficiency(e; kwargs...)

    @check_if_symbol e (:Miele2019,)

    if e == :Miele2019
        EfficiencyFromMiele2019(; kwargs...)
    else
        EfficiencyFromRawValues(e)
    end

end

export Efficiency

#-------------------------------------------------------------------------------------------
# First variant: user provides raw efficiency rates.

mutable struct EfficiencyFromRawValues <: Efficiency
    e::@GraphData {Scalar, SparseMatrix, Adjacency}{Float64}
    EfficiencyFromRawValues(e) = new(@tographdata e SEA{Float64})
end

function F.check(model, bp::EfficiencyFromRawValues)
    (; _A, _species_index) = model
    (; e) = bp
    @check_refs_if_list e "trophic link" _species_index template(_A)
    @check_template_if_sparse e _A "trophic link"
end

function F.expand!(model, bp::EfficiencyFromRawValues)
    (; _A, _species_index) = model
    (; e) = bp
    ind = _species_index
    @to_sparse_matrix_if_adjacency e ind ind
    @to_template_if_scalar Real e _A
    model.biorates.e = e
end

@component EfficiencyFromRawValues requires(Foodweb)
export EfficiencyFromRawValues

#-------------------------------------------------------------------------------------------
# Second variant: user provides herbivorous/carnivourous rates.

mutable struct EfficiencyFromMiele2019 <: Efficiency
    e_herbivorous::Float64
    e_carnivorous::Float64
    function EfficiencyFromMiele2019(; kwargs...)
        @kwargs_helpers kwargs
        eh = take_or!(:e_herbivorous, 0.45)
        ec = take_or!(:e_carnivorous, 0.85)
        no_unused_arguments()
        new(eh, ec)
    end
end

# TODO anything to check?
function F.expand!(model, bp::EfficiencyFromMiele2019)
    (; _herbivorous_links, _carnivorous_links) = model
    eh = bp.e_herbivorous
    ec = bp.e_carnivorous
    model.biorates.e = eh * _herbivorous_links + ec * _carnivorous_links
end

@component EfficiencyFromMiele2019 requires(Foodweb)
export EfficiencyFromMiele2019

#-------------------------------------------------------------------------------------------
# Don't specify simultaneously.
@conflicts(EfficiencyFromRawValues, EfficiencyFromMiele2019)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Efficiency}) = Efficiency

# ==========================================================================================
# These rates are terminal (yet): they can be both queried and modified.

@expose_data edges begin
    property(efficiency, e)
    get(EfficiencyRates{Float64}, sparse, "trophic link")
    ref(m -> m.biorates.e)
    template(m -> m._A)
    write!((m, rhs, i, j) -> (m.biorates.e[i, j] = rhs))
    @species_index
    depends(Efficiency)
end

# ==========================================================================================
# Display.

# Highjack display to make it like all blueprints provide the same component.
display_short(bp::Efficiency; kwargs...) = display_short(bp, Efficiency; kwargs...)
display_long(bp::Efficiency; kwargs...) = display_long(bp, Efficiency; kwargs...)

# Just display range.
function F.display(model, ::Type{<:Efficiency})
    nz = findnz(model._e)[3]
    "Efficiency: " * if isempty(nz)
        "·"
    else
        min, max = minimum(nz), maximum(nz)
        if min == max
            "$min"
        else
            "$min to $max."
        end
    end
end
