#=
Metabolic losses
=#

function metabolic_loss(i, B, params::ModelParameters)
    xᵢ = params.biorates.x[i] # metabolic rate of species i
    Bᵢ = B[i] # biomass of species i
    xᵢ * Bᵢ
end
