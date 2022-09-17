#=
Quantifying functions
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

"""
**Shannon's entropy**
Corrected for the number of species, removes negative and null values, return
`NaN` in case of problem.
"""
function shannon(n)
    x = copy(n)
    x = filter((k) -> k > 0.0, x)
    try
        if length(x) > 1
            p = x ./ sum(x)
            corr = log.(length(x))
            p_ln_p = p .* log.(p)
            return -(sum(p_ln_p)/corr)
        else
            return NaN
        end
    catch
        return NaN
    end
end

"""
**Food web diversity**
Based on the average of Shannon's entropy (corrected for the number of
species) over the last `last` timesteps. Values close to 1 indicate that
all populations have equal biomasses.
"""
function foodweb_evenness(solution; last=1000)
    @assert last <= length(solution.t) 
    measure_on = solution[:,end-(last-1):end]
    if sum(measure_on) == 0
        return NaN
    end
    shan = [shannon(vec(out[:,i])) for i in 1:size(out, 2)]
    return mean(shan)
end
