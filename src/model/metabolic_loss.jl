#=
Metabolic losses
=#

metabolic_loss(i, B, params::ModelParameters) = params.biorates.x[i] * B[i]
