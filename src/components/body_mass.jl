# Set or generate body masses for every species in the model.

# (reassure JuliaLS)
(false) && (local BodyMass, _BodyMass)

# ==========================================================================================
# Blueprints.

module BodyMassBlueprints
include("blueprint_modules.jl")
import .EcologicalNetworksDynamics: _Species, Species, _Foodweb, Foodweb

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

F.early_check(bp::Raw) =
    for (i, m) in enumerate(bp.M)
        try
            check(m)
        catch e
            checkrefails("Invalid M[$i]: $(e.message)")
        end
    end
check(m) = checkfails("Only positive values allowed, received $m.")

function F.late_check(raw, bp::Raw)
    (; M) = bp
    S = @get raw.S
    @check_size M S
end

F.expand!(raw, bp::Raw) = expand!(raw, bp.M)
expand!(raw, M) = raw._foodweb.M = M

#-------------------------------------------------------------------------------------------
# From a scalar broadcasted to all species.

mutable struct Flat <: Blueprint
    M::Float64
end
@blueprint Flat "homogeneous mass value" depends(Species)
export Flat

F.early_check(bp::Flat) = check(bp.M)
F.expand!(raw, bp::Flat) = expand!(raw, to_size(bp.M, @get raw.S))

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
    for (sp, m) in M
        try
            check(m)
        catch e
            checkrefails("Invalid M[$(repr(sp))]: $(e.message)")
        end
    end
end

function F.expand!(raw, bp::Map)
    index = @ref raw.species.index
    M = to_dense_vector(bp.M, index)
    expand!(raw, M)
end

#-------------------------------------------------------------------------------------------
# From trophic levels with a Z-value.

mutable struct Z <: Blueprint
    Z::Float64
end
@blueprint Z "trophic levels" depends(Foodweb)
export Z

function F.late_check(_, bp::Z)
    (; Z) = bp
    Z >= 0 || checkfails("Cannot calculate body masses from trophic levels \
                          with a negative value of Z: $Z.")
end

function F.expand!(raw, bp::Z)
    A = @ref raw.A
    M = Internals.compute_mass(A, bp.Z)
    expand!(raw, M)
end

end

# ==========================================================================================
# Component and generic constructors.

@component BodyMass{Internal} requires(Species) blueprints(BodyMassBlueprints)
export BodyMass

(::_BodyMass)(M::Real) = BodyMass.Flat(M)

function (::_BodyMass)(; Z = nothing)
    isnothing(Z) && argerr("Either 'M' or 'Z' must be provided to define body masses.")
    BodyMass.Z(Z)
end

function (::_BodyMass)(M)
    M = @tographdata M {Vector, Map}{Float64}
    if M isa Vector
        BodyMass.Raw(M)
    else
        BodyMass.Map(M)
    end
end

# Basic query.
@expose_data nodes begin
    property(body_masses, M)
    depends(BodyMass)
    @species_index
    ref(raw -> raw._foodweb.M)
    get(BodyMasses{Float64}, "species")
    write!(
        (raw, rhs, i) -> begin
            M = @ref raw.M
            rhs isa Real || #  HERE: this check should be a common thing to feature.
                writerr("not a real number: $(repr(rhs)) ::$(typeof(rhs)).")
            rhs >= 0 || writerr("not a positive value: $rhs.") # HERE: express with @expose_data.
            M[i] = rhs
        end,
    )
end

# Display.
function F.shortline(io::IO, model::Model, ::_BodyMass)
    print(io, "BodyMass: [$(join_elided(model.body_masses, ", "))]")
end
