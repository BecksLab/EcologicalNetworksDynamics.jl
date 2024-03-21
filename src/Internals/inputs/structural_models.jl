"""
    cascade_model(S::Int, C::AbstractFloat)

Generate an adjancency matrix using the cascade model
from a number of species `S` and a connectance `C`.

# Examples

```julia
cascade_model(10, 0.2)
```

See [Cohen et al. (1985)](https://doi.org/10.1098/rspb.1985.0042) for details.
"""
function cascade_model(S::Int, C::AbstractFloat)
    # Safety checks.
    C_max = ((S^2 - S) / 2) / (S * S)
    C > C_max && throw(
        ArgumentError(
            "Connectance for $S species cannot be larger than $C_max. " *
            "Given value of C=$C.",
        ),
    )
    C < 0 && throw(ArgumentError("Connectance must be positive. Given value of C=$C."))
    S <= 0 && throw(ArgumentError("Number of species must be positive."))
    # Build cascade matrix.
    A = zeros(Bool, S, S)
    rank_list = sort(rand(S); rev = true) # Rank species.
    p = 2 * C * S / (S - 1) # Probability for linking two species.
    for (consumer, rank) in enumerate(rank_list)
        # Consumer can feed on all resource with a smaller rank.
        potential_resources = findall(<(rank), rank_list)
        for resource in potential_resources
            rand() < p && (A[consumer, resource] = true)
        end
    end
    A
end

"""
    cascade_model(S::Int, L::Int)

Generate an adjancency matrix using the cascade model
from a number of species `S` and a number of links `L`.

# Examples

```julia
cascade_model(10, 3)
```

See [Cohen et al. (1985)](https://doi.org/10.1098/rspb.1985.0042) for details.
"""
function cascade_model(S::Int, L::Int)
    C = L / (S * S) # Corresponding connectance.
    cascade_model(S, C)
end

"""
    niche_model(S::Int, C::AbstractFloat)

Generate an adjancency matrix using the niche model
from a number of species `S` and a connectance `C`.

# Example

```julia
niche_model(10, 0.2)
```

See [Williams and Martinez (2000)](https://doi.org/10.1038/35004572) for details.
"""
function niche_model(S::Int, C::AbstractFloat)
    # Safety checks.
    C < 0 && throw(ArgumentError("Connectance must be positive. " * "Given value of C=$C."))
    S <= 0 && throw(ArgumentError("Number of species must be positive."))
    C >= 0.5 && throw(
        ArgumentError("The connectance cannot be larger than 0.5. Given value of C=$C."),
    )
    # Build niche matrix.
    A = zeros(Bool, S, S)
    beta = 1.0 / (2.0 * C) - 1.0 # Parameter for the beta distribution.
    body_size_list = sort(rand(S); rev = true)
    centroid_list = zeros(Float64, S)
    range_list = body_size_list .* rand(Beta(1.0, beta), S)
    centroid_list = [rand(Uniform(r / 2, m)) for (r, m) in zip(range_list, body_size_list)]
    range_list[S] = 0.0 # Smallest species has no range.
    for consumer in 1:S, resource in 1:S
        c = centroid_list[consumer]
        r = range_list[consumer]
        m = body_size_list[resource]
        if c - r / 2 < m < c + r / 2 # Check if resource is within consumer range.
            A[consumer, resource] = true
        end
    end
    A
end

"""
    niche_model(S::Int, C::AbstractFloat)

Generate an adjancency matrix using the niche model
from a number of species `S` and a number of links `L`.

# Example

```julia
niche_model(10, 20) # 20 links for 10 species.
```

```

See [Williams and Martinez (2000)](https://doi.org/10.1038/35004572) for details.
```
"""
function niche_model(S::Int, L::Int)
    L <= 0 &&
        throw(ArgumentError("Number of links L must be positive. Given value of L=$L."))
    C = L / (S * S)
    niche_model(S, C)
end
