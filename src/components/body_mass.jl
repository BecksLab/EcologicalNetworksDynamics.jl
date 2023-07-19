# Set or generate body masses for every species in the model.

# Body mass are either given as-is by user
# or they are calculated from the foodweb with a Z-value.
# As a consequence, component expansion only requires `Foodweb`
# in the second case.
# In spirit, this leads to the definition
# of "two different blueprints for the same component".

# ==========================================================================================
# Emulate this with an abstract blueprint type.

abstract type BodyMass <: ModelBlueprint end
# All subtypes must require(Species).

# Construct either variant based on user input.
function BodyMass(raw = nothing; Z = nothing, M = nothing)

    (!isnothing(raw) && !isnothing(M)) && argerr("Body masses 'M' specified twice:\n\
                                                  once as     : $(repr(raw))\n\
                                                  and once as : $(repr(M))")
    israw = !isnothing(raw) || !isnothing(M)
    isZ = !isnothing(Z)
    M = israw ? (isnothing(raw) ? M : raw) : nothing

    (!israw && !isZ) && argerr("Either 'M' or 'Z' must be provided to define body masses.")

    (israw && isZ) && argerr("Cannot provide both 'M' and 'Z' to specify body masses. \n\
                              Received M: $(repr(M))\n     \
                                   and Z: $(repr(Z)).")

    israw && return BodyMassFromRawValues(M)

    BodyMassFromZ(Z)
end

export BodyMass

#-------------------------------------------------------------------------------------------
# First variant: user provides raw body masses.

mutable struct BodyMassFromRawValues <: BodyMass
    M::@GraphData {Scalar, Vector, Map}{Float64}
    BodyMassFromRawValues(M) = new(@tographdata M SVK{Float64})
end

# Infer species compartment from body mass vector if given.
F.can_imply(bp::BodyMassFromRawValues, ::Type{Species}) = !(bp.M isa Real)
Species(bp::BodyMassFromRawValues) =
    if bp.M isa Vector
        Species(length(bp.M))
    else
        Species(refs(bp.M))
    end

function F.check(model, bp::BodyMassFromRawValues)
    (; S, _species_index) = model
    (; M) = bp
    @check_refs_if_list M :species _species_index dense
    @check_size_if_vector M S
end

function F.expand!(model, bp::BodyMassFromRawValues)
    (; S, _species_index) = model
    (; M) = bp
    @to_dense_vector_if_map M _species_index
    @to_size_if_scalar Real M S
    model._foodweb.M = M
end

@component BodyMassFromRawValues implies(Species)
export BodyMassFromRawValues

#-------------------------------------------------------------------------------------------
# Second variant: body masses are calculated from trophic levels.

mutable struct BodyMassFromZ <: BodyMass
    Z::@GraphData {Scalar}{Float64}
    BodyMassFromZ(Z) = new(@tographdata Z S{Float64})
end

function F.check(_, bp::BodyMassFromZ)
    (; Z) = bp
    Z >= 0 || checkfails(
        "Cannot calculate body masses from trophic levels with a negative value of Z: $Z.",
    )
end

function F.expand!(model, bp::BodyMassFromZ)
    (; Z) = bp
    A = model._foodweb.A
    M = Internals.compute_mass(A, Z)
    model._foodweb.M = M
end

@component BodyMassFromZ requires(Foodweb)
export BodyMassFromZ

#-------------------------------------------------------------------------------------------
# Don't specify both ways.
@conflicts(BodyMassFromRawValues, BodyMassFromZ)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:BodyMass}) = BodyMass

# ==========================================================================================
# Basic query.

@expose_data nodes begin
    property(body_masses, M)
    get(BodyMasses{Float64}, "species")
    ref(m -> m._foodweb.M)
    @species_index
    depends(BodyMass)
end

# ==========================================================================================
# Display.

# Highjack display to make it like both blueprints provide the same component.
display_short(bp::BodyMass; kwargs...) = display_short(bp, BodyMass; kwargs...)
display_long(bp::BodyMass; kwargs...) = display_long(bp, BodyMass; kwargs...)

function F.display(model, ::Type{<:BodyMass})
    "Body masses: [$(join_elided(model._body_masses, ", "))]"
end
