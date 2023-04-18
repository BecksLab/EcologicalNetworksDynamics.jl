#=
Quantifying functions.
=#

"""
    richness(solution::Solution; threshold = 0, kwargs...)

Returns the average number of species with a biomass larger than `threshold`
over the `last` timesteps. `kwargs...` are optional arguments passed to
[`extract_last_timesteps`](@ref).

# Arguments:

  - `solution`: output of `simulate()` or `solve()`
  - `threshold`: biomass threshold below which a species is considered extinct. Set to 0 by
    debault and it is recommended to let as this. It is recommended to change the threshold
    using [`ExtinctionCallback`](@ref) in [`simulate`](@ref).

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5];
       sol = simulate(params, B0);
       richness(sol; last = 10)
2.0

julia> sha = shannon_diversity(sol);
       round(sha; digits = 3)
0.69

julia> simp = simpson(sol);
       round(simp; digits = 3)
0.353

julia> even = evenness(sol);
       round(even; digits = 3)
0.996
```
"""
function richness(solution::Solution; threshold = 0, kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    rich = richness.(eachcol(measure_on); threshold)
    mean(rich)
end

"""
    richness(n::AbstractVector; threshold = 0)

When applied to a vector of biomass, returns the number of biomass above `threshold`

# Examples

```jldoctest
julia> richness([0, 1])
1

julia> richness([1, 1])
2
```
"""
richness(n::AbstractVector; threshold = 0) = sum(n .> threshold)

"""
    species_persistence(solution; kwargs...)

Returns the average proportion of species having a biomass superior or equal to threshold
over the `last` timesteps.

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

When applied to a vector of biomass, e.g.
`species_persistence(n::Vector; threshold = 0)`, it returns the proportion of
species which biomass is above `threshold`.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]; quiet = true);
       params = ModelParameters(foodweb);
       sim_two = simulate(params, [0.5, 0.5]);
       species_persistence(sim_two; last = 1)
1.0

julia> sim_one = simulate(params, [0, 0.5]);
       species_persistence(sim_one; last = 1)
0.5

julia> sim_zero = simulate(params, [0, 0]);
       species_persistence(sim_zero; last = 1)
0.0

julia> species_persistence([0, 1])
0.5

julia> species_persistence([1, 1])
1.0
```
"""
function species_persistence(solution; kwargs...)
    r = richness(solution; kwargs...)
    m = richness(get_parameters(solution).network)
    r / m
end
species_persistence(n::AbstractVector; threshold = 0) = richness(n; threshold) / length(n)

"""
    biomass(solution; kwargs...)

Returns a named tuple of total and species biomass, averaged over the `last` timesteps.

# Arguments

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

Can also handle a species x time biomass matrix, e.g. `biomass(mat::AbstractMatrix;)` or a
vector, e.g. `biomass(vec::AbstractVector;)`.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5];
       sol = simulate(params, B0);
       bm = biomass(sol; last = 2);
       biomass(sol; last = 2).species ≈ [0.1890006203352691, 0.21964742227673806]
true

julia> biomass(sol; last = 2, idxs = [1]); # Get biomass for one species only
       [biomass(sol; last = 2, idxs = [1]).total] ≈
       biomass(sol; last = 2, idxs = [1]).species ≈
       [0.1890006203352691]
true

julia> biomass([2 1; 4 2])
(total = 4.5, species = [1.5, 3.0])
```
"""
function biomass(solution; kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    biomass(measure_on)
end
biomass(mat::AbstractMatrix;) =
    (total = mean(vec(sum(mat; dims = 1))), species = mean.(eachrow(mat)))
biomass(vec::AbstractVector;) = (total = mean(vec), species = mean(vec))


"""
    shannon_diversity(solution; threshold = 0, kwargs...)

Computes the average Shannon entropy index, i.e. the first Hill number,
over the `last` timesteps.

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

Can also handle a vector, e.g. shannon_diversity(n::AbstractVector; threshold = 0)

# Reference

https://en.wikipedia.org/wiki/Diversity_index#Shannon_index
"""
function shannon_diversity(solution; threshold = 0, kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    shan = shannon_diversity.(eachcol(measure_on); threshold)
    mean(shan)
end

function shannon_diversity(n::AbstractVector; threshold = 0)
    x = filter(>(threshold), n)
    if length(x) >= 1
        p = x ./ sum(x)
        p_ln_p = p .* log.(p)
        sha = -(sum(p_ln_p))
    else
        sha = NaN
    end
    sha
end


"""
    simpson(solution; threshold = 0, kwargs...)

Computes the average Simpson diversity index, i.e. the second Hill number,
over the `last` timesteps.

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

Can also handle a vector, e.g. simpson(n::AbstractVector; threshold = 0)

# Reference

https://en.wikipedia.org/wiki/Diversity_index#Simpson_index
"""
function simpson(solution; threshold = 0, kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    simp = simpson.(eachcol(measure_on); threshold)
    mean(simp)
end

function simpson(n::AbstractVector; threshold = 0)
    x = filter(>(threshold), n)
    if length(x) >= 1
        p = x ./ sum(x)
        p2 = 2 .^ p
        simp = 1 / sum(p2)
    else
        simp = NaN
    end
    simp
end

"""
    evenness(solution; threshold = 0, kwargs...)

Computes the average Pielou evenness, over the `last` timesteps.

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

Can also handle a vector, e.g. `evenness(n::AbstractVector; threshold = 0)`

# Reference

https://en.wikipedia.org/wiki/Species_evenness
"""
function evenness(solution; threshold = 0, kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    piel = evenness.(eachcol(measure_on); threshold)
    mean(piel)
end

function evenness(n::AbstractVector; threshold = 0)
    x = filter(>(threshold), n)
    if length(x) > 0
        even = shannon_diversity(x) / log(length(x))
    else
        even = NaN
    end
    even
end

"""
    producer_growth(solution; kwargs...)

Returns the average growth rates of producers over the `last` timesteps as as well as the
average (`mean`) and the standard deviation (`std`). It also returns  by all the growth
rates (`all`) as a species x timestep matrix (as the solution matrix).

kwargs... arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 1 1; 0 0 0; 0 0 0]);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5, 0.5];
       sol = simulate(params, B0);
       g = producer_growth(sol; last = 10);
       g.species, round.(g.mean, digits = 2)
(["s2", "s3"], [0.15, 0.15])
```
"""
function producer_growth(solution; kwargs...)
    parameters = get_parameters(solution)
    producer_idxs = producers(parameters.network)
    producer_species = parameters.network.species[producer_idxs]

    Kp = parameters.environment.K[producer_idxs]
    rp = parameters.biorates.r[producer_idxs]
    αp = parameters.producer_competition.α[producer_idxs, producer_idxs]

    #Extract the producer_species biomass over the last timesteps
    measure_on = extract_last_timesteps(solution; idxs = producer_idxs, kwargs...)

    growth = zeros(length(producer_idxs), size(measure_on, 2))
    for (i, α) in enumerate(eachrow(αp)), (j, B) in enumerate(eachcol(measure_on))
        s = sum(α .* B)
        growth[i, j] = logisticgrowth(B[i], rp[i], Kp[i], s)
    end

    (
        species = producer_species,
        mean = mean.(eachrow(growth)),
        std = std.(eachrow(growth)),
        all = growth,
    )
end

"""
    get_extinct_species(sol)

Extract list of extinct species from the solution returned by `simulate()`.

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);
       params = ModelParameters(foodweb);
       sol = simulate(params, [0.5, 0.5]);
       isempty(get_extinct_species(sol)) # no species extinct
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
       params = ModelParameters(foodweb);
       sol = simulate(params, [0.5, 0.5]);
       isa(get_parameters(sol), ModelParameters)
true
```

See also [`simulate`](@ref), [`get_extinct_species`](@ref).
"""
get_parameters(sol) = sol.prob.p.params

"""
    trophic_structure(solution; threshold = 0, idxs = nothing, kwargs...)

Returns the maximum, mean and weighted mean trophic level averaged over the `last`
timesteps. It also returns the adjacency matrix containing only the living species and the
vector of the living species at the last timestep.

kwargs... arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5, 0.5];
       sol = simulate(params, B0; verbose = true);
       three_sp = trophic_structure(sol; last = 10);
       three_sp[(:max, :mean)]
(max = 2.0, mean = 1.3333333333333335)

julia> B0 = [0.5, 0.5, 0];
       sol = simulate(params, B0; verbose = true);
       no_consumer = trophic_structure(sol; last = 10);
       no_consumer[(:max, :mean)]
(max = 1.0, mean = 1.0)

julia> foodweb = FoodWeb([0 0 0; 0 1 0; 1 1 0]; quiet = true);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5, 0.5];
       sol = simulate(params, B0; verbose = false);
       sum(trophic_structure(sol; last = 1).alive_A) - sum(foodweb.A)
-2
```
"""
function trophic_structure(solution; threshold = 0, idxs = nothing, kwargs...)

    isnothing(idxs) ||
        throw(ArgumentError("`trophic_structure()` operates at the whole network level, \
                             so it makes no sense to ask for particular species \
                             with anything other than `idxs = nothing`."))


    # Measure trophic structure over last timesteps
    measure_on = extract_last_timesteps(solution; kwargs...)
    net = get_parameters(solution).network.A

    maxl = []
    meanl = []
    wmean = []
    for i in 1:size(measure_on, 2)
        alive = alive_trophic_network(measure_on[:, i], net; threshold)
        tlvl = alive.trophic_level
        bm = alive.species_biomass
        push!(maxl, max_trophic_level(tlvl))
        push!(meanl, mean_trophic_level(tlvl))
        push!(wmean, weighted_mean_trophic_level(bm, tlvl))
    end

    # Get the network at the last timestep
    alive = alive_trophic_network(measure_on[:, end], net; threshold)

    (
        max = mean(maxl),
        mean = mean(meanl),
        weighted_mean = mean(wmean),
        alive_species = alive.species,
        alive_trophic_level = alive.trophic_level,
        alive_A = alive.A,
    )
end

function trophic_structure(n::AbstractVector, A::AbstractMatrix; threshold = 0)

    alive = alive_trophic_network(n, A; threshold)
    tlvl = alive.trophic_level
    bm = alive.species_biomass

    (
        max = max_trophic_level(tlvl),
        mean = mean_trophic_level(tlvl),
        weighted_mean = weighted_mean_trophic_level(bm, tlvl),
        alive_species = alive.species,
        alive_trophic_level = tlvl,
        alive_A = alive.A,
    )
end

function alive_trophic_network(n::AbstractVector, A::AbstractMatrix; kwargs...)
    species = living_species(n; kwargs...)

    if isempty(species)
        A = []
        trophic_level = []
        species_biomass = []
    else
        A = A[species, species]
        trophic_level = trophic_levels(A)
        species_biomass = n[species]
    end

    (; species, species_biomass, trophic_level, A)
end

docstring = """
    max_trophic_level(solution::Solution; threshold = 0, kwargs...)
    mean_trophic_level(solution::Solution; threshold = 0, kwargs...)
    weighted_mean_trophic_level(solution::Solution; threshold = 0, kwargs...)

Return the aggregated trophic level over the `last` timesteps,
either with `max` or `mean` aggregation,
or by the mean trophic level weighted by species biomasses.

kwargs... arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

These functions also handle biomass vectors associated with a network, as well as
a vector of trophic levels (See examples).

# Examples

```jldoctest
julia> A = [0 0; 1 0];
       max_trophic_level(A)
2.0

julia> mean_trophic_level(A)
1.5

julia> bm = [1, 1];
       max_trophic_level(bm, A)
2.0

julia> mean_trophic_level(bm, A)
1.5

julia> weighted_mean_trophic_level(bm, A)
1.5

julia> bm = [0, 1];
       max_trophic_level(bm, A)
1.0

julia> mean_trophic_level(bm, A)
1.0

julia> weighted_mean_trophic_level(bm, A)
1.0

julia> foodweb = FoodWeb(A; quiet = true);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5];
       sol = simulate(params, B0; verbose = false);
       max_trophic_level(sol)
2.0

julia> mean_trophic_level(sol)
1.5

julia> w = weighted_mean_trophic_level(sol);
       round(w; digits = 2)
1.54
```
"""

# Use metaprog to generate the three functions in a row.
function aggregate_trophic_level(op_name, aggregate_function)
    op_trophic_level = Symbol(op_name, :_trophic_level)
    if isnothing(aggregate_function)
        from_matrices_code = :()
    else
        from_matrices_code = from_matrices(op_name, aggregate_function)
    end
    # Generate user-facing method, feeding from the solution.
    return quote

        @doc $docstring function $op_trophic_level(
            solution::Solution;
            threshold = 0,
            kwargs...,
        )
            measure_on = extract_last_timesteps(solution; kwargs...)
            net = get_parameters(solution).network.A

            out = []
            for i in 1:size(measure_on, 2)
                tmp = $op_trophic_level(measure_on[:, i], net; threshold)
                push!(out, tmp)
            end
            mean(out)
        end

        $from_matrices_code

    end
end

function from_matrices(op_name, aggregate_function)
    op_trophic_level = Symbol(op_name, :_trophic_level)
    # Generate underlying methods, feeding from raw matrices.
    return quote
        function $op_trophic_level(n::AbstractVector, A::AbstractMatrix; kwargs...)
            out = alive_trophic_network(n, A; kwargs...)
            tlvl = out.trophic_level
            $op_trophic_level(tlvl)
        end
        $op_trophic_level(A::AbstractMatrix;) = $op_trophic_level(trophic_levels(A))
        $op_trophic_level(tlvl::AbstractVector) =
            isempty(tlvl) ? NaN : $aggregate_function(tlvl)
    end
end

# Generation happens here.
eval(aggregate_trophic_level(:max, :maximum))
eval(aggregate_trophic_level(:mean, :mean))
eval(aggregate_trophic_level(:weighted_mean, nothing))

# The code differs slightly in the weighted_mean case.
function weighted_mean_trophic_level(n::AbstractVector, A::AbstractMatrix; kwargs...)
    out = alive_trophic_network(n, A; kwargs...)
    bm = out.species_biomass
    tlvl = out.trophic_level
    weighted_mean_trophic_level(bm, tlvl)
end
function weighted_mean_trophic_level(n::AbstractVector, tlvl::AbstractVector)
    if all(isempty.([tlvl, n]))
        w_mean = NaN
    else
        w_mean = sum(tlvl .* (n ./ sum(n)))
    end
    w_mean
end


"""
    living_species(solution::Solution; threshold = 0, idxs = nothing, kwargs...)

Returns the vectors of alive species and their indices in the original network.
Living species are the ones having, in average, a biomass above `threshold` over
the `last` timesteps. `kwargs...` are optional arguments passed to
[`extract_last_timesteps`](@ref).

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 1 1; 0 0 0; 0 0 0]);
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5, 0.5];
       sol = simulate(params, B0; verbose = true);

julia> living_species(sol)
(species = ["s1", "s2", "s3"], idxs = [1, 2, 3])

julia> B0 = [0, 0.5, 0.5];
       sol = simulate(params, B0; verbose = true);
       living_species(sol; last = 1)
(species = ["s2", "s3"], idxs = [2, 3])
```
"""
function living_species(solution::Solution; threshold = 0, idxs = nothing, kwargs...)

    measure_on = extract_last_timesteps(solution; idxs, kwargs...)
    alive_sp = living_species(measure_on; threshold)
    sp = get_parameters(solution).network.species

    tmp_idxs = process_idxs(solution; idxs)
    idxs = tmp_idxs[alive_sp]
    species = sp[idxs]

    (; species, idxs)
end

living_species(mat::AbstractMatrix; threshold = 0) =
    findall(>(threshold), biomass(mat).species)
living_species(n::AbstractVector; threshold = 0) = findall(>(threshold), n)

"""
    min_max(solution; kwargs...)

Returns the vectors of minimum and maximum biomass of each species over the `last`
timesteps.

`kwargs...` arguments are forwarded to [`extract_last_timesteps`](@ref). See
[`extract_last_timesteps`](@ref) for the argument details.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);
       params = ModelParameters(foodweb);
       sol = simulate(params, [0.5; 0.5]; tmax = 100);
       ti = min_max(sol; last = 10);
       round.(ti.min, digits = 3) # Min
2-element Vector{Float64}:
 0.168
 0.206

julia> round.(ti.max, digits = 3) # Max
2-element Vector{Float64}:
 0.196
 0.221
```
"""
function min_max(solution; kwargs...)
    measure_on = extract_last_timesteps(solution; kwargs...)
    (min = minimum.(eachrow(measure_on)), max = maximum.(eachrow(measure_on)))
end
