# Set or generate growth rates for every producer in the model.

# Like body masses, growth rates mass are either given as-is by user
# or they are calculated from other components if given correct allometric rates.
# Interestingly, allometric rates are either self-sufficient,
# or they require that a temperature be defined within the model.

# TODO: since only producers are involved,
# does it make sense to receive and process a full allometric dict here?

# (reassure JuliaLS)
(false) && (local GrowthRate, _GrowthRate)

# HERE: test after fixing JuliaLS.

# ==========================================================================================
# Blueprints.

module GR
include("blueprint_modules.jl")
include("blueprint_modules_identifiers.jl")
import .EcologicalNetworksDynamics:
    Species, _Species, BodyMass, MetabolicClass, _Temperature

#-------------------------------------------------------------------------------------------
# From raw values.

mutable struct Raw <: Blueprint
    r::SparseVector{Float64}
    species::Brought(Species)
    Raw(r::SparseVector{Float64}, sp = _Species) = new(r, sp)
    Raw(r, sp = _Species) = new(SparseVector(Float64.(r)), sp)
end
F.implied_blueprint_for(bp::Raw, ::_Species) = Species(length(bp.r))
@blueprint Raw "growth rate values"
export Raw

F.early_check(bp::Raw) =
    for (i, r) in zip(findnz(bp.r)...)
        check(r, i)
    end
check(r) = r >= 0 || checkfails("Not a positive value: r = $r.")
check(r, ref) = r >= 0 || checkfails("Not a positive value: r[$(repr(ref))] = $r.")

function F.late_check(raw, bp::Raw)
    (; r) = bp
    prods = @ref raw.producers.mask
    @check_template r prods :producers
end

F.expand!(raw, bp::Raw) = expand!(raw, bp.r)
function expand!(raw, r)
    # The legacy format is a dense vector.
    raw.biorates.r = collect(r)
    # Keep a true sparse version in the cache.
    raw._cache[:growth_rate] = r
end

#-------------------------------------------------------------------------------------------
# From a scalar broadcasted to all species.

mutable struct Flat <: Blueprint
    r::Float64
end
@blueprint Flat "homogeneous growth rate" depends(Species)
export Flat

F.early_check(bp::Flat) = check(bp.r)
F.expand!(raw, bp::Flat) = expand!(raw, to_template(bp.r, @get raw.producers.mask))

#-------------------------------------------------------------------------------------------
# From a species-indexed map.

mutable struct Map <: Blueprint
    r::@GraphData Map{Float64}
    species::Brought(Species)
    Map(r, sp = _Species) = new(@tographdata(r, Map{Float64}), sp)
end
F.implied_blueprint_for(bp::Map, ::_Species) = Species(refs(bp.r))
@blueprint Map "{species ↦ growth rate} map"
export Map

function F.late_check(raw, bp::Map)
    (; r) = bp
    index = @ref raw.species.index
    prods = @ref raw.producers.mask
    @check_list_refs r :species index template(prods)
    for (sp, m) in r
        check(m, sp)
    end
end

function F.expand!(raw, bp::Map)
    index = @ref raw.species.index
    r = to_sparse_vector(bp.r, index)
    expand!(raw, r)
end

#-------------------------------------------------------------------------------------------
# From allometric rates (no temperature).

miele2019_growth_allometry_rates() = Allometry(; producer = (a = 1, b = -1 / 4))

mutable struct Allometric <: Blueprint
    allometry::Allometry
    Allometric(; kwargs...) = new(parse_allometry_arguments(kwargs))
    Allometric(allometry::Allometry) = new(allometry)
    # Default values.
    function Allometric(default::Symbol)
        @check_symbol default (:Miele2019,)
        @expand_symbol default (:Miele2019 => new(miele2019_growth_allometry_rates()))
    end
end
@blueprint Allometric "allometric rates" depends(BodyMass, MetabolicClass)
export Allometric

function F.early_check(bp::Allometric)
    (; allometry) = bp
    @check_template allometry miele2019_growth_allometry_rates() "growth rates"
end

function F.expand!(raw, bp::Allometric)
    M = @ref raw.M
    mc = @ref raw.metabolic_classes
    prods = @ref raw.producers.mask
    r = sparse_nodes_allometry(bp.allometry, prods, M, mc)
    expand!(raw, r)
end

#-------------------------------------------------------------------------------------------
# From allometric rates and activation energy (temperature).

binzer2016_growth_allometry_rates() =
    (E_a = -0.84, allometry = Allometry(; producer = (a = exp(-15.68), b = -0.25)))

mutable struct Temperature <: Blueprint
    E_a::Float64
    allometry::Allometry
    Temperature(E_a; kwargs...) = new(E_a, parse_allometry_arguments(kwargs))
    Temperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function Temperature(default::Symbol)
        @check_symbol default (:Binzer2016,)
        @expand_symbol default (:Binzer2016 => new(binzer2016_growth_allometry_rates()...))
    end
end
@blueprint Temperature "allometric rates and activation energy" depends(
    _Temperature,
    BodyMass,
    MetabolicClass,
)
export Temperature

function F.early_check(bp::Temperature)
    (; allometry) = bp
    @check_template(
        allometry,
        binzer2016_growth_allometry_rates(),
        "growth rates (from temperature)",
    )
end

function F.expand!(raw, bp::Temperature)
    (; E_a) = bp
    T = @get raw.T
    M = @ref raw.M
    mc = @ref raw.metabolic_classes
    prods = @ref raw.producers.mask
    r = sparse_nodes_allometry(bp.allometry, prods, M, mc, E_a, T)
    expand!(raw, r)
end

end

# ==========================================================================================
# Component and generic constructors.

@component GrowthRate{Internal} requires(Foodweb) blueprints(GR)
export GrowthRate

# Construct either variant based on user input,
# but disallow direct allometric input in this constructor,
# because `GrowthRate(a_p=1, b_p=2)` could either be written
# by a user wanting simple allometry
# or by a user wanting temperature allometry
# and having forgotten to specify a value for `E_a`.
# Better stop them with an error then than keep going wit non-temperature-dependent values.
function (::_GrowthRate)(r)

    r = @tographdata r {Symbol, Vector, Map}{Float64}
    @check_if_symbol r (:Miele2019, :Binzer2016)

    if r == :Miele2019
        GrowthRate.Allometric(r)
    elseif r == :Binzer2016
        GrowthRate.Temperature(r)
    elseif r isa Vector
        GrowthRate.Raw(r)
    else
        GrowthRate.Map(r)
    end

end

# Basic query.
@expose_data nodes begin
    property(growth_rate, r)
    depends(GrowthRate)
    @species_index
    ref_cached(_ -> nothing) # Cache filled on component expansion.
    get(GrowthRates{Float64}, sparse, "producer")
    template(raw -> @ref raw.producers.mask)
    write!((raw, rhs::Real, i) -> begin
        GR.check(rhs)
        rhs = Float64(rhs)
        raw.biorates.r[i] = rhs
        rhs
    end)
end

# Display.
F.shortline(io::IO, model::Model, ::_GrowthRate) =
    print(io, "Growth rate: [$(join_elided(model._growth_rate, ", "))]")
