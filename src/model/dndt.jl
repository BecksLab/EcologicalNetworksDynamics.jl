"""
**Nutrient uptake**
"""
function dNdt(growthparams::NutrientIntake, l, B, N, G)
    D = growthparams.D
    S = growthparams.Sₗ[l]
    cli = growthparams.Cₗᵢ[l]
    return D * (S - N[l]) - sum(cli .* G .* B)
end

"""
**Nutrient uptake**
Methode for logistic growth rate
"""
function dNdt(growthparams::LogisticGrowth, l, B, N, G)
    return 0.0
end

