#=
Core functions of the model
=#

function dBdt!(du, B, Parameters::ModelParameters, t)

    B[B.<=0] .= 0 # ensuring non-negative biomass

    foodweb = Parameters.FoodWeb
    biorates = Parameters.BioRates
    environment = Parameters.Environment
    F = Parameters.FunctionalResponse

    growth = basalgrowth(B, foodweb, biorates, environment)
    eating, being_eaten = consumption(B, foodweb, biorates, F, environment)
    metabolic_loss = metaboliclosses(B, biorates)

    dBdt = growth .+ eating .- being_eaten .- metabolic_loss
    for i in eachindex(dBdt)
        du[i] = dBdt[i] #can't return du directly, have to have 2 different objects dBdt and du for some reason...
    end

    return dBdt
end
