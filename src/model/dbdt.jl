#=
Core functions of the model
=#

function dBdt!(dB, B, p, t)

    params, extinct_sp = p # unpack input

    S = richness(params.network)

    # Separate biomass and nutrients
    N = B[S+1:end]
    B = B[1:S]

    # Set up - Unpack parameters
    response_matrix = params.functional_response(B, params.network)
    r = params.biorates.r # vector of intrinsic growth rates
    network = params.network
    G = repeat([0.0], Int(S))

    # Compute ODE terms for each species
    for i in 1:S
        growth = params.producer_growth(i, B, r, network, N)
        G[i] = growth
        eating, being_eaten = consumption(i, B, params, response_matrix)
        metabolism_loss = metabolic_loss(i, B, params)
        natural_death = natural_death_loss(i, B, params)
        net_growth_rate = growth + eating - metabolism_loss
        net_growth_rate = effect_competition(net_growth_rate, i, B, network)
        dB[i] = net_growth_rate - being_eaten - natural_death
    end
    
    for j in S+1:S+length(N)
        l = j-S
        dB[j] = nutrient_dynamics(params.producer_growth, l, B, N, G)
    end
    
    # Avoid zombie species by forcing extinct biomasses to zero.
    # https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues/65
    for sp in keys(extinct_sp)
        B[sp] = 0.0
    end

    #recat B and N
    B = vcat(B,N)
end

