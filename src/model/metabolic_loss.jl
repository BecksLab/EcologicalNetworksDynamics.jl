#=
Metabolic losses
=#

metabolic_loss(i, B, params::ModelParameters) = params.biorates.x[i] * B[i]

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
