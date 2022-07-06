#=
Core functions of the model
=#

function dBdt!(dB, B, params::ModelParameters, t)

    # Set up - Unpack parameters
    S = richness(params.network)
    response_matrix = params.functional_response(B, params.network)
    r = params.biorates.r # vector of intrinsic growth rates
    K = params.environment.K # vector of carrying capacities
    network = params.network

    # Compute ODE terms for each species
    for i in 1:S
        growth = logisticgrowth(i, B, r[i], K[i], network)
        eating, being_eaten = consumption(i, B, params, response_matrix)
        metabolism_loss = metabolic_loss(i, B, params)
        net_growth_rate = growth + eating - metabolism_loss
        net_growth_rate = effect_competition(net_growth_rate, i, B, network)
        dB[i] = net_growth_rate - being_eaten
    end
end

"Effect of competition on the net growth rate."
function effect_competition(G_net, i, B, network::MultiplexNetwork)
    isproducer(i, network) || return G_net
    c0 = network.competition_layer.intensity
    competitors = network.competition_layer.A[:, i] # sp competing for space with sp i
    δG_net = c0 * sum(competitors .* B)
    network.refuge_layer.f(G_net, δG_net)
end
effect_competition(G_net, _, _, _::FoodWeb) = G_net

"""
Quantity describing the reduction of the net growth rate due to the competition for space.
We assume `competition_factor` ∈ [0,1].
"""
function competition_factor(i, B, network::MultiplexNetwork)
    isproducer(i, network) || return 1
    c0 = network.competition_layer.intensity
    A_competition = network.competition_layer.A
    competitors = A_competition[:, i] # species competing for space with species i
    max(0, 1 - c0 * sum(competitors .* B))
end
competition_factor(i, B, network::FoodWeb) = 1
