#### Type definition ####
mutable struct Environment
    K::Vector{Union{Nothing,<:Real}}
    T::Union{Int64,Float64}
end
#### end ####

#### Type display ####
"""
One line Environment display.
"""
function Base.show(io::IO, environment::Environment)
    K_str = vector_to_string(environment.K)
    T = environment.T
    print(io, "Environment(K=" * K_str * ", T=$(T)K)")
end

"""
Multiline Environment display.
"""
function Base.show(io::IO, ::MIME"text/plain", environment::Environment)

    # Display output
    println(io, "Environment:")
    println(io, "  K: " * vector_to_string(environment.K))
    print(io, "  T: $(environment.T) Kelvin")
end
#### end ####

"""
    Environment(foodweb, K=1, T=293.15)

Create environmental parameters of the system.

The environmental parameters are:

  - K the vector of carrying capacities
  - T the temperature (in Kelvin)
    By default, the carrying capacities of producers are assumed to be 1 while capacities of
    consumers are assumed to be `nothing` as consumers do not have a growth term.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # species 1 & 2 producers, 3 consumer

julia> environment = Environment(foodweb) # default behaviour
Environment:
  K: [1, 1, nothing]
  T: 293.15 Kelvin

julia> environment.K # 1 for producers (1 & 2), nothing for consumers (3)
3-element Vector{Union{Nothing, Real}}:
 1
 1
  nothing

julia> Environment(foodweb; K = 2).K # change the default value for producers
3-element Vector{Union{Nothing, Real}}:
 2
 2
  nothing

julia> Environment(foodweb; K = [1, 2, nothing]).K # can also provide a vector
3-element Vector{Union{Nothing, Real}}:
 1
 2
  nothing
```

See also [`ModelParameters`](@ref).
"""
function Environment(
    net::EcologicalNetwork;
    K::Union{Tp,Vector{Union{Nothing,Tp}},Vector{Tp}} = 1,
    T::Real = 293.15,
) where {Tp<:Real}
    S = richness(net)
    isa(K, AbstractVector) || (K = [isproducer(i, net) ? K : nothing for i in 1:S])
    @check_equal_richness length(K) S
    Environment(K, T)
end
