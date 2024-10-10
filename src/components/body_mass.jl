# Set or generate body masses for every species in the model.

# (reassure JuliaLS)
(false) && (local BodyMass)

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
    Map(M, sp = _Species) = new(@tographdata(M, Map{Float64}), sp)
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
    M::Vector{Float64}
    species::Brought(Species)
    Raw(M, sp = _Species) = new(Float64.(M), sp)
end
F.implied_blueprint_for(bp::Raw, ::_Species) = Species(length(bp.M))
@blueprint Raw "masses values"
export Raw

function F.late_check(raw, bp::Map)
    (; M) = bp
    S = @get raw.S
    @check_size M S
end

F.expand!(model, bp::Raw) = model._foodweb.M = bp.M

#-------------------------------------------------------------------------------------------
# From a scalar broadcasted to all species.

mutable struct Broadcast <: Blueprint
    M::Float64
end
@blueprint Broadcast "homogeneous mass value" depends(Species)
export Broadcast

F.expand!(model, bp::Raw) = model._noodweb.M = to_size(bp.M, @get raw.S)

end

# ==========================================================================================
# Component and generic constructor.

@component BodyMass{Internal} requires(Species) blueprints(BodyMassBlueprints)
export BodyMass

_BodyMass(M) = BodyMass.Raw(M)
_BodyMass(M::Number) = BodyMass.Broadcast(M)
_BodyMass(; Z = nothing) = isnothing(Z) && argerr("Either 'M' or 'Z' must be provided \
                                                   to define body masses.")

# Basic query.
@expose_data nodes begin
    property(body_masses, M)
    get(BodyMasses{Float64}, "species")
    ref(raw -> raw._foodweb.M)
    @species_index
    depends(BodyMass)
end

# Display.
function F.shortline(io::IO, model::Model, ::_BodyMass)
    print(io, "BodyMass: [$(join_elided(model.body_masses, ", "))]")
end
