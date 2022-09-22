#=
Various measures of stability
=#

"""
**Coefficient of variation**
Corrected for the sample size.
"""
function coefficient_of_variation(x)
    cv = std(x) / mean(x)
    norm = 1 + 1 / (4 * length(x))
    return norm * cv
end

"""
**Population stability**
Population stability is measured as the mean of the negative coefficient
of variations of all species with an abundance higher than `threshold`. By
default, the stability is measured over the last `last=1000` timesteps.

# Examples

```julia-repl
julia> foodweb = FoodWeb([0 1; 0 0]); # create a simple foodweb

julia> p = ModelParameters(foodweb) # default
ModelParameters{BioenergeticResponse}:
  network: FoodWeb(S=2, L=1)
  environment: Environment(K=[nothing, 1], T=293.15K)
  biorates: BioRates(e, r, x, y)
  functional_response: BioenergeticResponse

julia> bm = [.5, .5];

julia> sim = simulate(p, bm);

julia> producer_growth(sim, last = 3, out_type = :all) #default 

julia> producer_growth(sim, last = 50, out_type = :mean) # Average per species

julia> producer_growth(sim, last = 50, out_type = :std) # Sd per species 

julia> species_persistence(sim, last = 50)

julia> population_stability(sim, last = 50)

julia> total_biomass(sim, last = 50)

julia> foodweb_evenness(sim, last = 50)
```

"""
function population_stability(solution; threshold::Float64=eps(), last=1000)
    @assert last <= length(solution.t)
    non_extinct = solution[:, end] .> threshold
    measure_on = solution[non_extinct, end-(last-1):end]
    if sum(measure_on) == 0
        return NaN
    end
    stability = -mapslices(coefficient_of_variation, measure_on, dims = 2)
    return mean(stability)
end
