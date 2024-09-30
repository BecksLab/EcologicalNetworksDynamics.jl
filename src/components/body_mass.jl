# Set or generate body masses for every species in the model.

# (reassure JuliaLS)
(false) && (local BodyMass, _BodyMass)

# ==========================================================================================
# Blueprints.

module BodyMassBlueprints
using ..BlueprintModule
import .EcologicalNetworksDynamics: _Species, Species, _Foodweb, Foodweb

#-------------------------------------------------------------------------------------------
# Calculate from trophic levels with a Z-value.

mutable struct Z <: Blueprint
    z::Float64
end
@blueprint Z "trophic levels" depends(Foodweb)
export Z

function F.late_check(_, bp::Z)
    (; z) = bp
    z >= 0 || checkfails("Cannot calculate body masses from trophic levels \
                          with a negative value of Z: $z.")
end

function F.expand!(raw, bp::Z)
    (; z) = bp
    A = @ref raw.A
    M = Internals.compute_mass(A, z)
    raw._foodweb.M = M
end

#-------------------------------------------------------------------------------------------
# From a species-indexed map.

mutable struct Map <: Blueprint
    M::@GraphData Map{Float64}
    species::Brought(Species)
    BodyMassFromRawValues(M, sp = _Species) = new(@tographdata Map{Float64}, sp)
end
F.implied_blueprint_for(bp::Map, ::_Species) = Species(refs(bp.M))
@blueprint Map "{species ↦ mass} map"
export Map


function F.late_check(raw, bp::Map)
    (; M) = bp
    index = @ref raw.species.index
    @check_list_refs M :species index dense
end

function F.expand!(raw, bp::Map)
    (; M) = bp
    index = @ref raw.species.index
    M = to_dense_vector(M, index)
    raw._foodweb.M = M
end

#-------------------------------------------------------------------------------------------
# From raw values.

mutable struct Raw <: Blueprint
    M::Vector{Float64} # HERE: also accept scalar.
    species::Brought(Species)
    BodyMassFromRawValues(M, sp = _Species) = new(Float64.(M), sp)
end
F.implied_blueprint_for(bp::Raw, ::_Species) = Species(length(bp.M))
@blueprint Raw "masses values"
export Raw

function F.late_check(raw, bp::Map)
    (; M) = bp
    S = @get raw.S
    @check_size M S
end

function F.expand!(model, bp::BodyMassFromRawValues)
    (; M) = bp
    S = @get raw.S
    @to_size_if_scalar Real M S
    model._foodweb.M = M
end

end

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
