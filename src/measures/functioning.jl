#=
Quantifying functions
=#

"""
**Number of surviving species**
Number of species with a biomass larger than the `threshold`. The threshold is
by default set at `eps()`, which should be close to 10^-16.
"""
function species_richness(solution; threshold::Float64=eps(), last::Int64=1000)
    @assert last <= length(solution.t)
    measure_on = solution[:,end-(last-1):end]
    if sum(measure_on) == 0
        return NaN
    end
    richness = vec(sum(measure_on .> threshold, dims = 1))
    return mean(richness)
end

"""
**Proportion of surviving species**
Proportion of species with a biomass larger than the `threshold`. The threshold is
by default set at `eps()`, which should be close to 10^-16.
"""
function species_persistence(solution; threshold::Float64=eps(), last::Int64=1000)
    r = species_richness(solution, threshold=threshold, last=last)
    m = size(solution, 1) # Number of species is the number of rows in the biomass matrix
    return r/m
end

"""
**Total biomass**
Returns the sum of biomass, averaged over the last `last` timesteps.
"""
function total_biomass(solution; last=1000)
    @assert last <= length(solution.t)
    measure_on = solution[:,end-(last-1):end]
    if sum(measure_on) == 0
        return NaN
    end
    biomass = vec(sum(measure_on, dims = 1))
    return mean(biomass)
end
