#=
Core functions of the model
=#

function dBdt!(dB, B, p, t)

    params, extinct_sp = p # unpack input

    # Set up - Unpack parameters
    S = richness(params.network)
    response_matrix = params.functional_response(B, params.network)
    r = params.biorates.r # vector of intrinsic growth rates
    K = params.environment.K # vector of carrying capacities
    α = params.producer_competition.α # matrix of producer competition
    network = params.network

    # Compute ODE terms for each species
    for i in 1:S
        # sum(α[i, :] .* B)) measures competitive effects (s)
        growth = logisticgrowth(i, B, r[i], K[i], sum(α[i, :] .* B), network)
        eating, being_eaten = consumption(i, B, params, response_matrix)
        metabolism_loss = metabolic_loss(i, B, params)
        natural_death = natural_death_loss(i, B, params)
        net_growth_rate = growth + eating - metabolism_loss
        net_growth_rate = effect_competition(net_growth_rate, i, B, network)
        dB[i] = net_growth_rate - being_eaten - natural_death
    end

    # Avoid zombie species by forcing extinct biomasses to zero.
    # https://github.com/BecksLab/BEFWM2/issues/65
    for sp in keys(extinct_sp)
        B[sp] = 0.0
    end
end

function stoch_dBdt!(dB, B, p, t)

    params, extinct_sp = p # unpack input

    # Set up - Unpack parameters
    S = richness(params.network)
    fᵣmatrix = params.functional_response(B[1:S], params.network) # functional response matrix
    r = params.biorates.r # vector of intrinsic growth rates
    K = params.environment.K # vector of carrying capacities
    stochasticity = params.stochasticity
    stressor = params.stressor

    # Loop over species
    for i in 1:S

        # Compute ODE terms
        growth = stoch_logistic_growth(i, B, r[i], K[i], S, stochasticity)
        eating, being_eaten = stoch_consumption(i, B, params, fᵣmatrix)
        metabolism_loss = stoch_metabolic_loss(i, B, params)

        # Update dB/dt
        dB[i] = growth + eating - being_eaten - metabolism_loss
    end

    # Avoid zombie species by forcing extinct biomasses to zero.
    # https://github.com/BecksLab/BEFWM2/issues/65
    for sp in keys(extinct_sp)
        B[sp] = 0.0
    end

    # Loop over stochastic parameters
    for i in S+1:S+length(stochasticity.stochspecies)
        dB[i] = stochasticity.θ[i-S] * (stochasticity.μ[i-S] - B[i])
    end

    # Apply stress
    if stressor.addstressor == true
        if t >= stressor.start

            for i in 1:S
                if i in stochasticity.stochspecies
                    idx = first(findall(x -> x == i, stochasticity.stochspecies))
                    dB[S+idx] = stochasticity.θ[idx] * ((1 + (stressor.slope * (t-stressor.start))) - B[S+idx])
                else
                    params.biorates.r[i] = 1 + (stressor.slope * (t-stressor.start))
                end
            end
        end
    end

end

function noise_equations(dW, B, p, t)

    params, extinct_sp = p # unpack input
    FW = params.network
    S = richness(FW)

    for i in 1:S # These will be the biomass dynamics, and demographic stochasticity
        if B[i] <= 0.0
            dW[i] = 0.0
        else
            dW[i] = 1 / sqrt(B[i] / FW.M[i])
        end
    end

    for i in S+1:length(B)
        dW[i] = 1.0
    end

end
