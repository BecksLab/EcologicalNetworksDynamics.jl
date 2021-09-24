#=
Metabolic losses
=#

function metaboliclosses(biomass, BR::BioRates)
    losses = biomass .* BR.x
    return losses
end