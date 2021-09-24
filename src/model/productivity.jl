#=
Productivity
=#

function basalgrowth(biomass, BR::BioRates, E::Environment)
    G = 1 .- biomass ./ E.K
    return BR.r .* G .* biomass 
end