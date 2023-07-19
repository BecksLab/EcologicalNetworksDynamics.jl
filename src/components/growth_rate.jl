# Set or generate growth rates for every producer in the model.

# Like body masses, growth rates mass are either given as-is by user
# or they are calculated from other components if given correct allometric rates.
# Interestingly, allometric rates are either self-sufficient,
# or they require that a temperature be defined within the model.
# This leads to the definition
# of "three different blueprints for the same component".

# TODO: since only producers are involved,
# does it make sense to receive and process a full allometric dict here?

# ==========================================================================================

abstract type GrowthRate <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input,
# but disallow direct allometric input in this constructor,
# because `GrowthRate(a_p=1, b_p=2)` could either be written
# by a user wanting simple allometry
# or by a user wanting temperature allometry
# but having forgotten to specify a value for `E_a`.
# Better stop them with an error then than keep going wit non-temperature-dependent values.
function GrowthRate(r)

    @check_if_symbol r (:Miele2019, :Binzer2016)

    if r == :Miele2019
        GrowthRateFromAllometry(r)
    elseif r == :Binzer2016
        GrowthRateFromTemperature(r)
    else
        GrowthRateFromRawValues(r)
    end

end

export GrowthRate

#-------------------------------------------------------------------------------------------
# First variant: user provides raw growth rates.

mutable struct GrowthRateFromRawValues <: GrowthRate
    r::@GraphData {Scalar, SparseVector, Map}{Float64}
    GrowthRateFromRawValues(r) = new(@tographdata r SNK{Float64})
end

function F.check(model, bp::GrowthRateFromRawValues)
    (; _producers_mask, _producers_sparse_index) = model
    (; r) = bp

    # 'Dense' check to disallow missing producers.
    @check_refs_if_list r :producers _producers_sparse_index dense
    @check_template_if_sparse r _producers_mask :producers
end

function store_legacy_r!(model, r::SparseVector{Float64})
    # The legacy format is a dense vector.
    model.biorates.r = collect(r)
    # Keep a true sparse version in the cache.
    model._cache[:growth_rate] = r
end

function F.expand!(model, bp::GrowthRateFromRawValues)
    (; _producers_mask, _species_index) = model
    (; r) = bp

    @to_sparse_vector_if_map r _species_index
    @to_template_if_scalar Real r _producers_mask

    store_legacy_r!(model, r)
end

@component GrowthRateFromRawValues requires(Foodweb)
export GrowthRateFromRawValues

#-------------------------------------------------------------------------------------------
# Second variant: user provides allometric rates (no temperature).

miele2019_growth_allometry_rates() = Allometry(; producer = (a = 1, b = -1 / 4))

mutable struct GrowthRateFromAllometry <: GrowthRate
    allometry::Allometry
    GrowthRateFromAllometry(; kwargs...) = new(parse_allometry_arguments(kwargs))
    GrowthRateFromAllometry(allometry::Allometry) = new(allometry)
    # Default values.
    function GrowthRateFromAllometry(default::Symbol)
        @check_if_symbol default (:Miele2019,)
        @build_from_symbol default (:Miele2019 => new(miele2019_growth_allometry_rates()))
    end
end

F.buildsfrom(::GrowthRateFromAllometry) = [BodyMass, MetabolicClass]

function F.check(_, bp::GrowthRateFromAllometry)
    al = bp.allometry
    check_template(al, miele2019_growth_allometry_rates(), "growth rates")
end

function F.expand!(model, bp::GrowthRateFromAllometry)
    (; _M, _metabolic_classes, _producers_mask) = model
    r = sparse_nodes_allometry(bp.allometry, _producers_mask, _M, _metabolic_classes)
    store_legacy_r!(model, r)
end

@component GrowthRateFromAllometry requires(Foodweb)
export GrowthRateFromAllometry

#-------------------------------------------------------------------------------------------
# Last variant: user provides allometric rates and activation energy (temperature).

binzer2016_growth_allometry_rates() =
    (E_a = -0.84, allometry = Allometry(; producer = (a = exp(-15.68), b = -0.25)))

mutable struct GrowthRateFromTemperature <: GrowthRate
    E_a::Float64
    allometry::Allometry
    GrowthRateFromTemperature(E_a; kwargs...) = new(E_a, parse_allometry_arguments(kwargs))
    GrowthRateFromTemperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function GrowthRateFromTemperature(default::Symbol)
        @check_if_symbol default (:Binzer2016,)
        return @build_from_symbol default (
            :Binzer2016 => new(binzer2016_growth_allometry_rates()...)
        )
    end
end

F.buildsfrom(::GrowthRateFromTemperature) = [Temperature, BodyMass, MetabolicClass]

function F.check(_, bp::GrowthRateFromTemperature)
    al = bp.allometry
    (_, template) = binzer2016_growth_allometry_rates()
    check_template(al, template, "growth rates from temperature")
end

function F.expand!(model, bp::GrowthRateFromTemperature)
    (; _M, T, _metabolic_classes, _producers_mask) = model
    (; E_a) = bp
    r = sparse_nodes_allometry(
        bp.allometry,
        _producers_mask,
        _M,
        _metabolic_classes;
        E_a,
        T,
    )
    store_legacy_r!(model, r)
end

@component GrowthRateFromTemperature requires(Foodweb)
export GrowthRateFromTemperature

#-------------------------------------------------------------------------------------------
# Don't specify simultaneously.
@conflicts(GrowthRateFromRawValues, GrowthRateFromAllometry, GrowthRateFromTemperature)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:GrowthRate}) = GrowthRate

# ==========================================================================================
# These rates are terminal (yet): they can be both queried and modified.

@expose_data nodes begin
    property(growth_rate, r)
    get(GrowthRates{Float64}, sparse, "producer")
    ref_cache(m -> nothing) # Cache loaded on component expansion.
    template(m -> m._producers_mask)
    write!((m, rhs, i) -> (m.biorates.r[i] = rhs))
    @species_index
    depends(GrowthRate)
end

# ==========================================================================================
# Display.

# Highjack display to make it like all blueprints provide the same component.
display_short(bp::GrowthRate; kwargs...) = display_short(bp, GrowthRate; kwargs...)
display_long(bp::GrowthRate; kwargs...) = display_long(bp, GrowthRate; kwargs...)

F.display(model, ::Type{<:GrowthRate}) =
    "GrowthRate: [$(join_elided(model._growth_rate, ", "))]"
