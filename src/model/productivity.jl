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

"Effect of facilitation on intrinsic growth rate."
function effect_facilitation(r, i, B, network::MultiplexNetwork)
    f0 = network.facilitation_layer.intensity
    facilitating_species = network.facilitation_layer.A[:, i]
    δr = f0 * sum(B .* facilitating_species)
    network.facilitation_layer.f(r, δr)
end
