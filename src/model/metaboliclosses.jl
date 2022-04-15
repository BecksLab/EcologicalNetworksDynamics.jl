#=
Metabolic losses
=#

function metaboliclosses(B, biorates::BioRates)
    B .* biorates.x
end
