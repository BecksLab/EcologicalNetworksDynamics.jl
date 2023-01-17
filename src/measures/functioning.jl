#=
Quantifying functions
Adapted from BioenergeticFoodWeb.jl
=#

"""
**Richness**
return `NaN` in case of problem.

# Argument

  - n: a vector of biomass values
"""
species_richness(n; threshold::Float64 = eps()) = sum(n .> threshold)

"""
**Number of surviving species**
Number of species with a biomass larger than the `threshold`. The threshold is
by default set at `eps()`, which should be close to 10^-16.
"""
function foodweb_richness(solution; threshold::Float64 = eps(), last::Int64 = 1000)
    measure_on = filter_sim(solution; last = last)

    rich = [
        species_richness(vec(measure_on[:, i]); threshold = threshold) for
        i in 1:size(measure_on, 2)
    ]
    return mean(rich)
end

"""
**Proportion of surviving species**
Proportion of species with a biomass larger than the `threshold`. The threshold is
by default set at `eps()`, which should be close to 10^-16.

Number of species is the species richness over the `last` timesteps (See [`foodweb_richness`](@ref)).

The number of species at the beginning of the simulation is the number of initial biomasses provided, i.e.
what the starting number of species would be

See also [`population_stability`](@ref)

# Examples

# 

```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]; quiet = true); # A foodweb of two producers

julia> params = ModelParameters(foodweb);

julia> sim_two = simulate(params, [0.5, 0.5]);

julia> species_persistence(sim_two; last = 1) # All the producers survived
1.0

julia> sim_one = simulate(params, [0, 0.5]);

julia> species_persistence(sim_one; last = 1) # Half of the producers survived
0.5

julia> sim_zero = simulate(params, [0, 0]);

julia> species_persistence(sim_zero; last = 1) # I know... It is a feature!
0.0
```
"""
function species_persistence(solution; threshold::Float64 = eps(), last::Int64 = 1000)
    r = foodweb_richness(solution; threshold = threshold, last = last)
    m = size(solution, 1) # Number of species is the number of rows in the biomass matrix
    return r / m
end

"""
**Total biomass**
Returns the sum of biomass, averaged over the last `last` timesteps.

See also [`population_stability`](@ref)
"""
function total_biomass(solution; last::Int64 = 1000)

    measure_on = filter_sim(solution; last = last)
    biomass = vec(sum(measure_on; dims = 1))
    return mean(biomass)
end



"""
**Shannon's diversity**
return `NaN` in case of problem.

# Argument

  - n: a vector of biomass values
"""
function shannon(n; threshold::Float64 = eps())
    x = copy(n)
    x = filter((k) -> k > threshold, x)
    try
        if length(x) >= 1
            p = x ./ sum(x)
            corr = log.(length(x))
            p_ln_p = p .* log.(p)
            return -(sum(p_ln_p))
        else
            return NaN
        end
    catch
        return NaN
    end
end

"""
**Foodweb Shannon diversity**

Equivalent of [`foodweb_richness`](@ref) for the Shannon entropy index (the first Hill number)

See also [`population_stability`](@ref) for examples
"""
function foodweb_shannon(solution; last::Int64 = 1000, threshold::Float64 = eps())
    measure_on = filter_sim(solution; last = last)

    if sum(measure_on) == 0
        return NaN
    end
    shan = [
        shannon(vec(measure_on[:, i]); threshold = threshold) for i in 1:size(measure_on, 2)
    ]
    return mean(shan)
end

"""
**Simpson's diversity**
return `NaN` in case of problem.

# Argument

  - n: a vector of biomass values
"""
function simpson(n; threshold::Float64 = eps())
    x = copy(n)
    x = filter((k) -> k > threshold, x)
    try
        if length(x) >= 1
            p = x ./ sum(x)
            p2 = 2 .^ p
            return 1 / sum(p2)
        else
            return NaN
        end
    catch
        return NaN
    end
end

"""
**Food web simpson**

Equivalent of [`foodweb_evenness`](@ref) for the Simpson diversity index (the second hill number)

See also [`population_stability`](@ref) for examples
"""
function foodweb_simpson(solution; last::Int64 = 1000, threshold::Float64 = eps())

    measure_on = filter_sim(solution; last = last)
    if sum(measure_on) == 0
        return NaN
    end
    piel = [
        simpson(vec(measure_on[:, i]); threshold = threshold) for i in 1:size(measure_on, 2)
    ]
    return mean(piel)
end

"""
**Pielou evenness**

Shannon divided by the log number of species

# See also

[`shannon`](@ref)
"""
function pielou(n; threshold::Float64 = eps())
    x = copy(n)
    x = filter((k) -> k > threshold, x)
    try
        if length(x) > 0
            return shannon(n) / log(length(x))
        else
            return NaN
        end
    catch
        return NaN
    end
end

"""
**Food web diversity**
Based on the average of Pielou Evenness index over the last `last` timesteps. Values close to 1 indicate that
all populations have equal biomasses.

See also [`population_stability`](@ref) for examples
"""
function foodweb_evenness(solution; last::Int64 = 1000, threshold::Float64 = eps())
    measure_on = filter_sim(solution; last = last)
    if sum(measure_on) == 0
        return NaN
    end
    piel = [
        pielou(vec(measure_on[:, i]); threshold = threshold) for i in 1:size(measure_on, 2)
    ]
    return mean(piel)
end



"""
**Producers growth rate**
This function takes the simulation outputs from `simulate` and returns the producer
growth rates. Depending on the value given to the keyword `out_type`, it can return
more specifically:

  - growth rates for each producer over the last `last` time steps (`out_type = :all`)
  - the mean growth rate for each producer over the last `last` time steps (`out_type = :mean`)
  - the standard deviation of the growth rate for each producer over the last `last` time steps (`out_type = :std`)

See also [`population_stability`](@ref)
"""
function producer_growth(solution; last::Int64 = 1000, out_type::Symbol = :all)
    parameters = get_parameters(solution) # extract parameters

    mask_producer = parameters.network.metabolic_class .== "producer"

    producer_species = parameters.network.species[mask_producer]

    Kp = parameters.environment.K[mask_producer]
    rp = parameters.biorates.r[mask_producer]

    # extract the biomasses of the producer_species
    measure_on = filter_sim(solution; last = last)[mask_producer, :]

    growth = (
        s = producer_species,
        G = [
            logisticgrowth.(measure_on[i, :], Kp[i], rp[i]) for i in 1:size(measure_on, 1)
        ],
    )

    if out_type == :all #return all growth rates (each producer at each time step)
        return growth
    elseif out_type == :mean #return the producers mean growth rate over the last `last` time steps
        return (s = producer_species, G = map(x -> mean(x), growth.G))
    elseif out_type == :std #return the growth rate standard deviation over the last `last` time steps (for each producer)
        return (s = producer_species, G = map(x -> std(x), growth.G))
    else #if the keyword used is not one of :mean, :all or :std, print an error
        error("out_type should be one of :all, :mean or :std")
    end
end

"""
    get_extinct_species(sol)

Extract list of extinct species from the solution returned by `simulate()`.

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> params = ModelParameters(foodweb);

julia> sol = simulate(params, [0.5, 0.5]);

julia> isempty(get_extinct_species(sol)) # no species extinct
true
```

See also [`simulate`](@ref), [`get_parameters`](@ref).
"""
get_extinct_species(sol) = sol.prob.p.extinct_sp

"""
    get_parameters(sol)

Extract the [`ModelParameters`](@ref) input from the solution returned by `simulate()`.

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> params = ModelParameters(foodweb);

julia> sol = simulate(params, [0.5, 0.5]);

julia> isa(get_parameters(sol), ModelParameters)
true
```

See also [`simulate`](@ref), [`get_extinct_species`](@ref).
"""
get_parameters(sol) = sol.prob.p.params
