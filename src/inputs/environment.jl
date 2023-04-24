#### Type definition ####
mutable struct Environment
    T::Union{Int64,Float64}
end
#### end ####

#### Type display ####
"""
One line Environment display.
"""
function Base.show(io::IO, environment::Environment)
    T = environment.T
    print(io, "Environment(" * "T=$(T)K)")
end

"""
Multiline Environment display.
"""
function Base.show(io::IO, ::MIME"text/plain", environment::Environment)

    # Display output
    println(io, "Environment:")
    print(io, "  T: $(environment.T) Kelvin")
end
#### end ####

"""
    Environment(foodweb, T=293.15)

Create environmental parameters of the system.

The environmental parameters are:

  - T the temperature (in Kelvin)
    By default, the carrying capacities of producers are assumed to be 1 while capacities of
    consumers are assumed to be `nothing` as consumers do not have a growth term.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # species 1 & 2 producers, 3 consumer

julia> environment = Environment(foodweb) # default behaviour
Environment:
  T: 293.15 Kelvin


julia> Environment(foodweb; T = 300.15).T # change temperature
Environment:
  T: 300.15 Kelvin
```

See also [`ModelParameters`](@ref).
"""
function Environment(
    net::EcologicalNetwork;
    T::Real = 293.15,
) where {Tp<:Real}
    Environment(T)
end
