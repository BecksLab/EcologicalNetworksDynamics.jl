"""
    environment()

TODO
"""
function Environment(
    foodweb::FoodWeb;
    K::Union{Tp,Vector{Union{Nothing,Tp}},Vector{Tp}}=1,
    T::Real=293.15
) where {Tp<:Real}

    S = richness(foodweb)

    # Test
    length(K) ∈ [1, S] || throw(ArgumentError("Wrong length: K should be of length 1 or S
        (species richness)."))

    # Format if needed
    length(K) == S || (K = [isproducer(foodweb, i) ? K : nothing for i in 1:S])

    Environment(K, T)
end
