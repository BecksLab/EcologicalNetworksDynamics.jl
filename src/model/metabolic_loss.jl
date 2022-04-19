#=
Metabolic losses
=#

function metabolic_loss(B, biorates::BioRates)
    B .* biorates.x
end
