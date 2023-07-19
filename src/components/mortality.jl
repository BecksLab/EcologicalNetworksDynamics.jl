# Set or generate mortality rates for every species in the model.
#
# Two blueprint variants "for the same component",
# depending on whether raw values or allometric rules are used.

# ==========================================================================================
abstract type Mortality <: ModelBlueprint end
# All subtypes must require(Species).

function Mortality(d)

    @check_if_symbol d (:Miele2019,)

    if d == :Miele2019
        MortalityFromAllometry(d)
    else
        MortalityFromRawValues(d)
    end

end

export Mortality

#-------------------------------------------------------------------------------------------
mutable struct MortalityFromRawValues <: Mortality
    d::@GraphData {Scalar, Vector, Map}{Float64}
    MortalityFromRawValues(d) = new(@tographdata d SVK{Float64})
end

F.can_imply(bp::MortalityFromRawValues, ::Type{Species}) = !(bp.d isa Real)
Species(bp::MortalityFromRawValues) =
    if bp.d isa Vector
        Species(length(bp.d))
    else
        Species(refs(bp.d))
    end

function F.check(model, bp::MortalityFromRawValues)
    (; S, _species_index) = model
    (; d) = bp
    @check_refs_if_list d :species _species_index dense
    @check_size_if_vector d S
end

function F.expand!(model, bp::MortalityFromRawValues)
    (; S, _species_index) = model
    (; d) = bp
    @to_dense_vector_if_map d _species_index
    @to_size_if_scalar Real d S
    model.biorates.d = d
end

@component MortalityFromRawValues implies(Species)
export MortalityFromRawValues

#-------------------------------------------------------------------------------------------
miele2019_mortality_allometry_rates() = Allometry(;
    producer = (a = 0.0138, b = -1 / 4),
    ectotherm = (a = 0.0314, b = -1 / 4),
    invertebrate = (a = 0.0314, b = -1 / 4),
)

mutable struct MortalityFromAllometry <: Mortality
    allometry::Allometry
    MortalityFromAllometry(; kwargs...) = new(parse_allometry_arguments(kwargs))
    MortalityFromAllometry(allometry::Allometry) = new(allometry)
    function MortalityFromAllometry(default::Symbol)
        @check_if_symbol default (:Miele2019,)
        return @build_from_symbol default (
            :Miele2019 => new(miele2019_mortality_allometry_rates())
        )
    end
end

F.buildsfrom(::MortalityFromAllometry) = [BodyMass, MetabolicClass]

function F.check(_, bp::MortalityFromAllometry)
    al = bp.allometry
    check_template(al, miele2019_mortality_allometry_rates(), "mortality rate")
end

function F.expand!(model, bp::MortalityFromAllometry)
    (; _M, _metabolic_classes) = model
    d = dense_nodes_allometry(bp.allometry, _M, _metabolic_classes)
    model.biorates.d = d
end

@component MortalityFromAllometry requires(Foodweb)
export MortalityFromAllometry

#-------------------------------------------------------------------------------------------
@conflicts(MortalityFromRawValues, MortalityFromAllometry)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Mortality}) = Mortality

# ==========================================================================================
@expose_data nodes begin
    property(mortality, d)
    get(MortalityRates{Float64}, "species")
    ref(m -> m.biorates.d)
    write!((m, rhs, i) -> (m.biorates.d[i] = rhs))
    @species_index
    depends(Mortality)
end

# ==========================================================================================
display_short(bp::Mortality; kwargs...) = display_short(bp, Mortality; kwargs...)
display_long(bp::Mortality; kwargs...) = display_long(bp, Mortality; kwargs...)
F.display(model, ::Type{<:Mortality}) =
    "Mortality: [$(join_elided(model._mortality, ", "))]"
