mutable struct Environment
    T::Float64
end

"""
One line Environment display.
"""
function Base.show(io::IO, environment::Environment)
    T = environment.T
    print(io, "Environment(T=$(T)K)")
end

"""
Multiline Environment display.
"""
function Base.show(io::IO, ::MIME"text/plain", environment::Environment)
    println(io, "Environment:")
    print(io, "  T: $(environment.T) Kelvin")
end

"""
    Environment(; T=293.15)

Create environmental parameters of the system, which are currently only temperature (T, in
Kelvin). The temperature default value is 293.15 Kelvins, i.e. 20 Celcius degrees.

# Arguments:
  - `T`: temperature in Kelvin

# Examples

```jldoctest
julia> e = Environment() # Default behaviour.
       e.T == 293.15 # Kelvin
true

julia> e = Environment(; T = 300.0)
       e.T == 300.0
true
```

See also [`ModelParameters`](@ref).
"""
Environment(; T = 293.15) = Environment(T)
