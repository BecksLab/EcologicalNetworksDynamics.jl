#=
Metabolic losses
=#

function metabolic_loss(i, B, params::ModelParameters)
    xᵢ = params.BioRates.x[i] # metabolic rate of species i
    Bᵢ = B[i] # biomass of species i
    xᵢ * Bᵢ
end
