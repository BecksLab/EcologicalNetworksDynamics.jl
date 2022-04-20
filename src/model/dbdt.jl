#=
Core functions of the model
=#

function dBdt!(dB, B, params::ModelParameters, t)

    B[B.<=0] .= 0 # ensuring non-negative biomass

    # Set up
    S = richness(params.FoodWeb)
    fᵣmatrix = params.FunctionalResponse(B) # functional response matrix

    # Loop over species
    for i in 1:S

        # Compute ODE terms
        growth = logisticgrowth(i, B, params)
        eating, being_eaten = consumption(i, B, params, fᵣmatrix)
        metabolism_loss = metabolic_loss(i, B, params)

        # Update dB/dt
        dB[i] = growth + eating - being_eaten - metabolism_loss
    end
end
