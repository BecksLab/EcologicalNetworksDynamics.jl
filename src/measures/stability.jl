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
default, the stability is measured over the last `last=50` timesteps.
"""
function population_stability(sim; threshold::Float64=eps(), last=50)
    @assert last <= size(sim[:B], 1)
    non_extinct = sim[:B][end,:] .> threshold
    measure_on = sim[:B][end-(last-1):end,non_extinct]
    if sum(measure_on) == 0
        return NaN
    end
    stability = -mapslices(coefficient_of_variation, measure_on, dims = 1)
    return mean(stability)
end