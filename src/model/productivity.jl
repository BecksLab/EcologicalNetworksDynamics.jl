#=
Productivity
=#

function logisticgrowth(i, B, r, K, s, network::MultiplexNetwork)
    r = effect_facilitation(r, i, B, network)
    logisticgrowth(B[i], r, K, s)
end

logisticgrowth(i, B, r, K, s, _::FoodWeb) = logisticgrowth(B[i], r, K, s)
logisticgrowth(i, B, r, K, ::FoodWeb) = logisticgrowth(B[i], r, K, B[i])

logisticgrowth(i, B, r, K, network::MultiplexNetwork) =
    logisticgrowth(i, B, r, K, B[i], network::MultiplexNetwork)

function logisticgrowth(B, r, K, s = B)
    !isnothing(K) || return 0
    r * B * (1 - s / K)
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

#=
If biomass is over carrying capacity (which would have G go negative)
and intrinsic growth rate  is negative (possible with stochasticity)
then the double negative sends biomass to infinity
So now we are breaking G into two parts,
Adding stochasticity to the growth part but not the density dependent loss part
=#

function stoch_logistic_growth(i, B, rᵢ, Kᵢ, S, stochasticity::AddStochasticity)
    if i ∈ stochasticity.stochproducers
        pᵢ = B[S+first(findall(x -> x == i, stochasticity.stochspecies))] # stochastic intrinsic growth rate of species i
        separatedlogisticgrowth(B[i], rᵢ, pᵢ, Kᵢ)
    else
        logisticgrowth(B[i], rᵢ, Kᵢ)
    end
end

function separatedlogisticgrowth(B, r, p, K)
    !isnothing(K) || return 0 # if carrying capacity is null, growth is null too (avoid NaNs)
    (p * B) - ((r * B^2) / K)
end
