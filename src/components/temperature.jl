# Temperature is a single graph-level scalar
# useful to calculate allometric values for various biorates.
#
# TODO: as model data, temperature gets invalidated as soon as a biorate is edited.
#       Is this a problem, and if yes, how to solve it?

mutable struct Temperature <: ModelBlueprint
    T::Float64 # (Kelvin)
    Temperature(T = 293.15) = new(T)
end

function F.check(_, bp::Temperature)
    (; T) = bp
    T >= 0.0 || checkfails("Temperature needs to be positive. Received: T = $T.")
end

function F.expand!(model, bp::Temperature)
    (; T) = bp
    model.environment = Internals.Environment(T)
end

@component Temperature
export Temperature

@expose_data graph begin
    property(temperature, T)
    get(m -> m.environment.T)
    depends(Temperature)
end

F.display(model, ::Type{<:Temperature}) = "Temperature: $(model.T)K"
