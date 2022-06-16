#=
Productivity
=#

function logisticgrowth(i, B, r, K, network::MultiplexNetwork)
    r = effect_facilitation(r, i, B, network)
    logisticgrowth(B[i], r, K)
end
logisticgrowth(i, B, r, K, _::FoodWeb) = logisticgrowth(B[i], r, K)

function logisticgrowth(B, r, K)
    !isnothing(K) || return 0
    r * B * (1 - B / K)
end
# Code generation version (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
function logisticgrowth(i, parms::ModelParameters)
    B_i = :(B[$i])
    r_i = parms.biorates.r[i]
    K_i = parms.environment.K[i]
    (r_i == 0 || isnothing(K_i)) && return 0
    :($r_i * $B_i * (1 - $B_i / $K_i))
end
