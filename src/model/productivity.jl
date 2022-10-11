#=
Productivity
=#

function logisticgrowth(i, B, r, K, s, network::MultiplexNetwork)
    r = effect_facilitation(r, i, B, network)
    logisticgrowth(B[i], r, K, s[i])
end
logisticgrowth(i, B, r, K, s, _::FoodWeb) = logisticgrowth(B[i], r, K, s[i])
logisticgrowth(i, B, r, K, _::FoodWeb) = logisticgrowth(B[i], r, K, B[i])
logisticgrowth(i, B, r, K, network::MultiplexNetwork) =
    logisticgrowth(i, B, r, K, B, network::MultiplexNetwork)

function logisticgrowth(B, r, K, s = B)
    !isnothing(K) || return 0
    r * B * (1 - s / K)
end
# Code generation version (raw) (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
function logisticgrowth(i, parms::ModelParameters)
    B_i = :(B[$i])
    r_i = parms.biorates.r[i]
    K_i = parms.environment.K[i]
    (r_i == 0 || isnothing(K_i)) && return 0
    :($r_i * $B_i * (1 - $B_i / $K_i))
end

# Code generation version (compact):
# Explain how to efficiently construct all values of growth.
# This code assumes that dB[i] has already been *initialized*.
function growth(parms::ModelParameters, ::Symbol)

    # Pre-calculate skips over non-primary producers.
    data = Dict(
        :primary_producers => [
            (i, r, K) for
            (i, (r, K)) in enumerate(zip(parms.biorates.r, parms.environment.K)) if
            (r != 0 && !isnothing(K))
        ],
    )

    code = [:(
        for (i, r_i, K_i) in primary_producers #  (skips over null terms)
            dB[i] += r_i * B[i] * (1 - B[i] / K_i)
        end
    )]

    code, data
end
