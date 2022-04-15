#=
Core functions of the model
=#

function dBdt!(dB, B, Parameters::ModelParameters, t)

    B[B.<=0] .= 0 # ensuring non-negative biomass

    foodweb = Parameters.FoodWeb
    biorates = Parameters.BioRates
    environment = Parameters.Environment
    F = Parameters.FunctionalResponse

    growth = logisticgrowth(B, foodweb, biorates, environment)
    eating, being_eaten = consumption(B, foodweb, biorates, F, environment)
    metabolic_loss = metaboliclosses(B, biorates)

    dB = growth .+ eating .- being_eaten .- metabolic_loss
end
