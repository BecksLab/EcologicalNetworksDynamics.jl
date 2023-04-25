"""
    nutrient_dynamics(p::ProducerGrowth, i, u, G, network::EcologicalNetwork)

Compute the dynamics of the nutrient `i` given the biomass `B`,
the nutrients abundances `N` and the vector of species growths `G`.

The nutrient dynamics is on only if `p` is of type `NutrientIntake`.
"""
function nutrient_dynamics(model::ModelParameters, u, i, G)
    p = model.producer_growth
    if isa(p, LogisticGrowth)
        throw(ArgumentError("Nutrient dynamics cannot be computed for producer growth \
                            of type `LogisticGrowth`."))
    end
    B = u[species(model)] # Species biomass.
    N = u[nutrients(model)] # Nutrient abundances.
    nutrient_idx = findfirst(==(i), nutrients(model)) # Index of the nutrient `i`.
    d = p.turnover[nutrient_idx]
    s = p.supply[nutrient_idx]
    c = p.concentration[:, nutrient_idx]
    d * (s - N[nutrient_idx]) - sum(c .* G .* B)
end
