# Temperature is a single graph-level scalar
# useful to calculate allometric values for various biorates.

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
