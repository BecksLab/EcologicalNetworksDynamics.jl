# Producer growth functors.
function (g::LogisticGrowth)(i, u, params::ModelParameters)
    isnothing(g.K[i]) && return 0.0 # Species i is not a producer.
    B = u[species_indexes(params)]
    network = params.network
    r = params.biorates.r
    r_i = isa(network, MultiplexNetwork) ? effect_facilitation(r[i], i, B, network) : r[i]
    s = sum(g.a[i, :] .* B)
    r_i * B[i] * (1 - s / g.K[i])
end

function (g::NutrientIntake)(i, u, params::ModelParameters)
    isproducer(i, params.network) || return 0.0
    network = params.network
    B = u[species_indexes(params)]
    N = u[nutrient_indexes(params)]
    r = params.biorates.r
    r_i = isa(network, MultiplexNetwork) ? effect_facilitation(r[i], i, B, network) : r[i]
    growth(N, k) = (N, k) == (0, 0) ? 0 : N / (N + k)
    growth_vec = growth.(N, g.half_saturation[i, :])
    r_i * B[i] * minimum(growth_vec)
end

# Code generation version (raw) (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
function logisticgrowth(i, parms::ModelParameters)
    B_i = :(B[$i])

    # Non-producers are dismissed right away.
    r_i = parms.biorates.r[i]
    K_i = parms.environment.K[i]
    (r_i == 0 || isnothing(K_i)) && return 0

    # Only consider nonzero competitors.
    α_i = parms.producer_competition.α[i, :]
    competitors = findall(α_i .!= 0)
    α_i = α_i[competitors]
    C = xp_sum([:c, :α], (competitors, α_i), :(α * B[c]))

    :($r_i * $B_i * (1 - $C / $K_i))
end

# Code generation version (compact):
# Explain how to efficiently construct all values of growth.
# This code assumes that dB[i] has already been *initialized*.
function growth(parms::ModelParameters, ::Symbol)

    # Pre-calculate skips over non-primary producers.
    S = richness(parms.network)
    data = Dict{Symbol,Any}(
        :primary_producers => [
            (i, r, K) for
            (i, (r, K)) in enumerate(zip(parms.biorates.r, parms.environment.K)) if
            (r != 0 && !isnothing(K))
        ],
    )

    # Flatten the e matrix with the same 'ij' indexing principle,
    # but for producers competition links 'ic' instead of predation links.
    # This should change in upcoming refactoring of compact code generation
    # when MultiplexNetwork is supported,
    # because a generic way accross all layers is needed for future compatibility.
    α = parms.producer_competition.α
    is, cs = findnz(α)
    data[:α] = [α[i, c] for (i, c) in zip(is, cs)]
    data[:producers_competition_links] = (is, cs)
    # Scratchspace to recalculate the sums on every timestep.
    # /!\ Reset during iteration in 'consumption'.
    # This will change in future evolution of :compact generated code
    data[:s] = zeros(S)

    code = [
        :(
            for (ic, (i, c)) in enumerate(zip(producers_competition_links...))
                s[i] += α[ic] * B[c]
            end
        ),
        :(
            for (i, r_i, K_i) in primary_producers #  (skips over null terms)
                dB[i] += r_i * B[i] * (1 - s[i] / K_i)
            end
        ),
    ]

    code, data
end

"""
    nutrient_dynamics(model::ModelParameters, u, i, G)

Compute the dynamics of the nutrient `i_nutrient` given its abundance `n`,
the species biomass `B` and the vector of species growths `G` and the model `p`.

The nutrient dynamics is on only if `p` is of type `NutrientIntake`.
"""
function nutrient_dynamics(model::ModelParameters, B, i_nutrient, n, G)
    p = model.producer_growth
    if isa(p, LogisticGrowth)
        throw(ArgumentError("Nutrient dynamics cannot be computed for producer growth \
                            of type `$LogisticGrowth`."))
    end
    d = p.turnover[i_nutrient]
    s = p.supply[i_nutrient]
    c = p.concentration[:, i_nutrient]
    d * (s - n) - sum(c .* G .* B)
end
