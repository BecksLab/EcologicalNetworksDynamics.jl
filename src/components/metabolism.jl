# Set or generate metabolism rates for every species in the model.

# Three blueprint variants "for the same component",
# depending on whether raw values or allometric rules
# with/without temperature response are used.

# ==========================================================================================
abstract type Metabolism <: ModelBlueprint end
# All subtypes must require(Species).

function Metabolism(x)

    @check_if_symbol x (:Miele2019, :Binzer2016)

    if x == :Miele2019
        MetabolismFromAllometry(x)
    elseif x == :Binzer2016
        MetabolismFromTemperature(x)
    else
        MetabolismFromRawValues(x)
    end

end

export Metabolism

#-------------------------------------------------------------------------------------------
mutable struct MetabolismFromRawValues <: Metabolism
    x::@GraphData {Scalar, Vector, Map}{Float64}
    MetabolismFromRawValues(x) = new(@tographdata x SVK{Float64})
end

F.can_imply(bp::MetabolismFromRawValues, ::Type{Species}) = !(bp.x isa Real)
Species(bp::MetabolismFromRawValues) =
    if bp.x isa Vector
        Species(length(bp.x))
    else
        Species(refs(bp.x))
    end

function F.check(model, bp::MetabolismFromRawValues)
    (; S, _species_index) = model
    (; x) = bp
    @check_refs_if_list x :species _species_index dense
    @check_size_if_vector x S
end

function F.expand!(model, bp::MetabolismFromRawValues)
    (; S, _species_index) = model
    (; x) = bp
    @to_dense_vector_if_map x _species_index
    @to_size_if_scalar Real x S
    model.biorates.x = x
end

@component MetabolismFromRawValues implies(Species)
export MetabolismFromRawValues

#-------------------------------------------------------------------------------------------
miele2019_metabolism_allometry_rates() = Allometry(;
    producer = (a = 0, b = 0),
    invertebrate = (a = 0.314, b = -1 / 4),
    ectotherm = (a = 0.88, b = -1 / 4),
)

mutable struct MetabolismFromAllometry <: Metabolism
    allometry::Allometry
    MetabolismFromAllometry(; kwargs...) = new(parse_allometry_arguments(kwargs))
    MetabolismFromAllometry(allometry::Allometry) = new(allometry)
    function MetabolismFromAllometry(default::Symbol)
        @check_if_symbol default (:Miele2019,)
        return @build_from_symbol default (
            :Miele2019 => new(miele2019_metabolism_allometry_rates())
        )
    end
end

F.buildsfrom(::MetabolismFromAllometry) = [BodyMass, MetabolicClass]

function F.check(_, bp::MetabolismFromAllometry)
    al = bp.allometry
    check_template(al, miele2019_metabolism_allometry_rates(), "metabolism rate")
end

function F.expand!(model, bp::MetabolismFromAllometry)
    (; _M, _metabolic_classes) = model
    x = dense_nodes_allometry(bp.allometry, _M, _metabolic_classes)
    model.biorates.x = collect(x)
end

@component MetabolismFromAllometry requires(Foodweb)
export MetabolismFromAllometry

#-------------------------------------------------------------------------------------------
binzer2016_metabolism_allometry_rates() = (
    E_a = -0.69,
    allometry = Allometry(;
        producer = (a = 0, b = -0.31), # ? Is that intended @hanamayall?
        invertebrate = (a = exp(-16.54), b = -0.31),
        ectotherm = (a = exp(-16.54), b = -0.31),
    ),
)

mutable struct MetabolismFromTemperature <: Metabolism
    E_a::Float64
    allometry::Allometry
    MetabolismFromTemperature(E_a; kwargs...) = new(E_a, parse_allometry_arguments(kwargs))
    MetabolismFromTemperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function MetabolismFromTemperature(default::Symbol)
        @check_if_symbol default (:Binzer2016,)
        return @build_from_symbol default (
            :Binzer2016 => new(binzer2016_metabolism_allometry_rates()...)
        )
    end
end

F.buildsfrom(::MetabolismFromTemperature) = [Temperature, BodyMass, MetabolicClass]

function F.check(_, bp::MetabolismFromTemperature)
    al = bp.allometry
    (_, template) = binzer2016_metabolism_allometry_rates()
    check_template(al, template, "metabolism rate from temperature")
end

function F.expand!(model, bp::MetabolismFromTemperature)
    (; _M, T, _metabolic_classes) = model
    (; E_a) = bp
    x = dense_nodes_allometry(bp.allometry, _M, _metabolic_classes; E_a, T)
    model.biorates.x = x
end

@component MetabolismFromTemperature requires(Foodweb)
export MetabolismFromTemperature

#-------------------------------------------------------------------------------------------
@conflicts(MetabolismFromRawValues, MetabolismFromAllometry, MetabolismFromTemperature)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Metabolism}) = Metabolism

# ==========================================================================================
@expose_data nodes begin
    property(metabolism, x)
    get(MetabolismRates{Float64}, "species")
    ref(m -> m.biorates.x)
    write!((m, rhs, i) -> (m.biorates.x[i] = rhs))
    @species_index
    depends(Metabolism)
end

# ==========================================================================================
display_short(bp::Metabolism; kwargs...) = display_short(bp, Metabolism; kwargs...)
display_long(bp::Metabolism; kwargs...) = display_long(bp, Metabolism; kwargs...)
F.display(model, ::Type{<:Metabolism}) =
    "Metabolism: [$(join_elided(model._metabolism, ", "))]"
