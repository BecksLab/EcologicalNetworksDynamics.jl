#=
Various measures of stability
=#

"""
*Compute Average temporal CV of the species*

# Arguments:

  - mat: A time x species matrix (typically the transposition of the output of `DifferentialEquations.solve()`)
"""
function avg_cv_sp(mat)

    avg_sp = mean.(eachcol(mat))
    std_sp = std.(eachcol(mat))

    rel_sp = avg_sp ./ sum(avg_sp)
    rel_sd_sp = std_sp ./ avg_sp

    avg_cv_sp = sum(rel_sp .* rel_sd_sp)

    return avg_cv_sp

end

"""
*Compute synchrony among species*

# Arguments:

  - mat: A time x species matrix (typically the transposition of the output of `DifferentialEquations.solve()`)
"""
function synchrony(mat)

    cov_mat = cov(mat)

    com_var = sum(cov_mat)
    std_sp = sum(std.(eachcol(mat)))

    phi = com_var / std_sp^2

    return phi
end

"""
*Compute synchrony among species*

# Arguments:

  - mat: A time x species matrix (typically the transposition of the output of `DifferentialEquations.solve()`)
"""
function temporal_cv(mat)

    total_com_bm = sum.(eachrow(mat))
    cv_com = std(total_com_bm) / mean(total_com_bm)

    return cv_com
end

"""
*Compute biomass stability*

# Arguments:

  - solution: output of BEFWM2.simulate()
  - threshold: threshold to consider that a species is extinct
  - last: the number of timesteps to consider

# Output: a named tuple with Community CV (cv_com) and its partition in average

population stability (avg_cv_sp) and species synchrony (sync)
"""
function foodweb_cv(solution; threshold::Float64 = eps(), last = 1000)

    measure_on = BEFWM2.filter_sim(solution; last = last)

    # Transpose to get the time x species matrix
    mat = transpose(measure_on)

    cv_sp = avg_cv_sp(mat)
    sync = synchrony(mat)

    cv_com = temporal_cv(mat)

    out = (cv_com = cv_com, avg_cv_sp = cv_sp, synchrony = sync)

    return out
end

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

julia> bm = [0.5, 0.5];

julia> sim = simulate(p, bm);

julia> producer_growth(sim; last = 3, out_type = :all) #default

julia> producer_growth(sim; last = 50, out_type = :mean) # Average per species

julia> producer_growth(sim; last = 50, out_type = :std) # Sd per species

julia> species_persistence(sim; last = 50)

julia> population_stability(sim; last = 50)

julia> total_biomass(sim; last = 50)

julia> foodweb_evenness(sim; last = 50)

```
"""
function population_stability(solution; threshold::Float64 = eps(), last = 1000)
    @assert last <= length(solution.t)
    non_extinct = solution[:, end] .> threshold
    measure_on = solution[non_extinct, end-(last-1):end]
    if sum(measure_on) == 0
        return NaN
    end
    stability = -mapslices(coefficient_of_variation, measure_on; dims = 2)
    return mean(stability)
end


"""
**Dominant eigenvalue**
"""

"""
Calculation of the jacobian using finite differences takes two arguments;
    Need the equations, and the biomass

    'When an equilibrium is linearly stable, the real parts of all of the eigenvalues are negative.
     The dominant eigenvalue is the one with the least negative real part' - Patterson 2021

BEFW_equations rephrases dBdt! such that it only takes B(iomass) as an argument.
To ensure the correct biomass at equilibrium is matched with the correct equations, dominant_eigenvalue takes a simulate output as an argument
"""
function BEFW_equations(B)

    # Set up - Unpack parameters
    S = richness(params.network)
    fᵣmatrix = params.functional_response(B, params.network) # functional response matrix
    r = params.biorates.r # vector of intrinsic growth rates
    K = params.environment.K # vector of carrying capacities
    network = params.network
    dB = copy(B)

    # Loop over species
    for i in 1:S

        # Compute ODE terms
        growth = logisticgrowth(i, B, r[i], K[i], network)
        eating, being_eaten = consumption(i, B, params, fᵣmatrix)
        metabolism_loss = metabolic_loss(i, B, params)
        net_growth_rate = growth + eating - metabolism_loss
        cᵢ = net_growth_rate >= 0 ? competition_factor(i, B, network) : 1

        # Update dB/dt
        dB[i] = cᵢ * net_growth_rate - being_eaten
    end
    return dB
end

function dominant_eigenvalue(params::ModelParameters, B::Vector{Float64})

    jac = FiniteDiff.finite_difference_jacobian(BEFW_equations, B)

    return maximum(real.(eigvals(jac)))
end
