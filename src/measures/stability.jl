#=
Various measures of stability.
=#

"""
    species_cv(solution::Solution; threshold = 0, last = "10%", kwargs...)

Computes the temporal coefficient of variation of species biomass and calculates the mean.

See [`coefficient_of_variation`](@ref) for the details.
"""
function species_cv(solution::Solution; threshold = 0, last = "10%", kwargs...)
    measure_on = extract_last_timesteps(solution; last, kwargs...)

    # Fetch species that are alive, whose mean biomass is > threshold
    living_sp = living_species(measure_on; threshold)

    # Transpose to get the time x species matrix
    mat = transpose(measure_on[living_sp, :])

    species_cv(mat)
end

function species_cv(mat::AbstractMatrix; corrected = true)
    if any(size(mat) .== 0)
        mn = NaN
        species = NaN
    else
        mean_sp = mean.(eachcol(mat))
        std_sp = std.(eachcol(mat); corrected)

        rel_sp = mean_sp ./ sum(mean_sp)
        rel_sd_sp = std_sp ./ mean_sp

        mn = sum(rel_sp .* rel_sd_sp)
        species = std_sp ./ mean_sp
    end
    (; mean = mn, species)
end

"""
    synchrony(
        solution::Solution;
        threshold = 0,
        last = "10%",
        corrected = true,
        kwargs...,
    )

Compute the synchrony of species biomass fluctuations following
Loreau & de Mazancourt (2008).

See [`coefficient_of_variation`](@ref) for the argument details.

# Reference:

Loreau, M., & de Mazancourt, C. (2008). Species Synchrony and Its Drivers :
Neutral and Nonneutral Community Dynamics in Fluctuating Environments. The
American Naturalist, 172(2), E48‑E66. https://doi.org/10.1086/589746
"""
function synchrony(
    solution::Solution;
    threshold = 0,
    last = "10%",
    corrected = true,
    kwargs...,
)
    measure_on = extract_last_timesteps(solution; last, kwargs...)

    # Fetch species that are alive, whose mean biomass is > threshold
    living_sp = living_species(measure_on; threshold)

    # Transpose to get the time x species matrix
    mat = transpose(measure_on[living_sp, :])

    synchrony(mat; corrected = corrected)
end

function synchrony(mat::AbstractMatrix; corrected = true)
    if any(size(mat) .== 0)
        phi = NaN
    else
        cov_mat = cov(mat; corrected)

        com_var = sum(cov_mat)
        std_sp = sum(std.(eachcol(mat); corrected))

        phi = com_var / std_sp^2
    end
    phi
end

"""
    community_cv(
        solution::Solution;
        threshold = 0,
        last = "10%",
        corrected = true,
        kwargs...,
    )

Compute the temporal Coefficient of Variation of community biomass.

See [`coefficient_of_variation`](@ref) for the argument details.
"""
function community_cv(
    solution::Solution;
    threshold = 0,
    last = "10%",
    corrected = true,
    kwargs...,
)
    measure_on = extract_last_timesteps(solution; last, kwargs...)

    # Fetch species that are alive, whose mean biomass is > threshold
    living_sp = living_species(measure_on; threshold, kwargs...)

    # Transpose to get the time x species matrix
    mat = transpose(measure_on[living_sp, :])

    community_cv(mat; corrected)
end

function community_cv(mat::AbstractMatrix; corrected = true)
    if any(size(mat) .== 0)
        cv_com = NaN
    else
        total_com_bm = sum.(eachrow(mat))
        cv_com = std(total_com_bm; corrected) / mean(total_com_bm)
    end
    cv_com
end

"""
    coefficient_of_variation(
        solution::Solution;
        threshold = 0,
        last = "10%",
        corrected = true,
        kwargs...,
    )

Computes the Coefficient of Variation (CV) of community biomass and its partition in
average species CV and synchrony, following Thibault & Connolly (2013).

The function excludes dead species, i.e. species that have an average biomass
below `threshold` over the `last` timesteps (see [`living_species`](@ref)). It
avoids division by 0 in the CV computation. `last` = "10%" by default.
We set `corrected = true` by default (see [`Statistics.std`](@ref)) which computes an
unbiaised estimator of the variance.

See [`richness`](@ref) for the argument details.

# Reference:

Thibaut, L. M., & Connolly, S. R. (2013). Understanding diversity–stability
relationships : Towards a unified model of portfolio effects. Ecology Letters,
16(2), 140‑150. https://doi.org/10.1111/ele.12019

# Examples:

```jldoctest
julia> foodweb = FoodWeb([0 1 1; 0 0 0; 0 0 0]); # Two producers and one consumer
       params = ModelParameters(foodweb);
       B0 = [0.5, 0.5, 0.5];
       sol = simulate(params, B0; verbose = true);
       key = (:community, :species_mean, :synchrony);
       s = coefficient_of_variation(sol; last = 10)[key];
       keys(s), round.(values(s); digits = 2)
((:community, :species_mean, :synchrony), (0.02, 0.06, 0.1))

julia> B0 = [0, 0.5, 0.5]; # Two producers
       sol = simulate(params, B0; verbose = true);
       s = coefficient_of_variation(sol; last = 10)[key];
       keys(s), round.(values(s); digits = 2)
((:community, :species_mean, :synchrony), (0.15, 0.15, 1.0))
```
"""
function coefficient_of_variation(
    solution::Solution;
    threshold = 0,
    last = "10%",
    corrected = true,
    kwargs...,
)
    measure_on = extract_last_timesteps(solution; last, kwargs...)
    # Fetch species that are alive, whose mean biomass is > threshold
    alive_sp = living_species(measure_on; threshold)

    # Transpose to get the time x species matrix
    mat = transpose(measure_on[alive_sp, :])

    cvsp = species_cv(mat; corrected)
    sync = synchrony(mat; corrected)
    cv_com = community_cv(mat; corrected)

    (community = cv_com, species_mean = cvsp.mean, synchrony = sync, species = cvsp.species)
end
