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
    metabolic_loss = metabolic_loss(B, biorates)

    # Update dB/dt
    dB = growth .+ eating .- being_eaten .- metabolic_loss
end
