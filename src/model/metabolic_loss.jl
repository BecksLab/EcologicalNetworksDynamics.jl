#=
Metabolic losses
=#

function metabolic_loss(i, B, params::ModelParameters)
    xᵢ = params.biorates.x[i] # metabolic rate of species i
    Bᵢ = B[i] # biomass of species i
    xᵢ * Bᵢ
end

function competition_factor(i, B, network::FoodWeb)
    1
end

"""
Quantity describing the reduction of the net growth rate due to the competition for space.
We assume `competition_factor` ∈ [0,1].
"""
function competition_factor(i, B, network::MultiplexNetwork)
    isproducer(network, i) || return 1
    c0 = network.competition_layer.intensity
    A_competition = network.competition_layer.A
    competitors = A_competition[:, i] # species competing for space with species i
    max(0, 1 - c0 * sum(competitors .* B))
end
