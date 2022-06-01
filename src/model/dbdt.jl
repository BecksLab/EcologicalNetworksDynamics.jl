#=
Core functions of the model
=#

function dBdt!(dB, B, params::ModelParameters, t)

    B[B.<=0] .= 0 # ensuring non-negative biomass

    # Set up - Unpack parameters
    S = richness(params.network)
    fᵣmatrix = params.functional_response(B, params.network) # functional response matrix
    r = params.biorates.r # vector of intrinsic growth rates
    K = params.environment.K # vector of carrying capacities
    network = params.network

    # Loop over species
    for i in 1:S

        # Compute ODE terms
        growth = logisticgrowth(i, B, r[i], K[i], network)
        eating, being_eaten = consumption(i, B, params, fᵣmatrix)
        metabolism_loss = metabolic_loss(i, B, params)

        # Update dB/dt
        dB[i] = growth + eating - being_eaten - metabolism_loss
    end
end
