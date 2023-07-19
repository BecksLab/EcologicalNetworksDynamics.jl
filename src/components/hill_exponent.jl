# Set or generate hill-exponent.

mutable struct HillExponent <: ModelBlueprint
    h::Float64
    HillExponent(h) = new(h)
end

function F.check(_, bp::HillExponent)
    (; h) = bp
    h >= 0.0 || checkfails("Hill exponent needs to be positive. Received: h = $h.")
end

function F.expand!(model, bp::HillExponent)
    (; h) = bp
    model._scratch[:hill_exponent] = h
end

@component HillExponent
export HillExponent

@expose_data graph begin
    property(hill_exponent, h)
    get(m -> m._scratch[:hill_exponent])
    set!((m, rhs::Float64) -> begin
        m._scratch[:hill_exponent] = rhs
        # Legacy updates, required because scalars don't alias.
        # Should not be needed once the Internals have been refactored.
        fr = m.functional_response
        fr isa Internals.BioenergeticResponse && (fr.h = rhs)
        fr isa Internals.ClassicResponse && (fr.h = rhs)
    end)
    depends(HillExponent)
end

F.display(model, ::Type{<:HillExponent}) = "Hill exponent: $(model.h)"
