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
