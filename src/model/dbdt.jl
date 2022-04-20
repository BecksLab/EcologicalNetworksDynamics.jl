#=
Core functions of the model
=#

function dBdt!(dB, B, Parameters::ModelParameters, t)

    B[B.<=0] .= 0 # ensuring non-negative biomass

    # Define parameters
    foodweb = Parameters.FoodWeb
    biorates = Parameters.BioRates
    environment = Parameters.Environment
    F = Parameters.FunctionalResponse

    # Compute equation terms
    growth = logisticgrowth(B, foodweb, biorates, environment)
    eating, being_eaten = consumption(B, foodweb, biorates, F, environment)
    metabolism_loss = metabolic_loss(B, biorates)

    # Update dB/dt
    S = richness(foodweb)
    for i in 1:S
        dB[i] = growth[i] + eating[i] - being_eaten[i] - metabolism_loss[i]
    end
end
