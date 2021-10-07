#=
Core functions of the model
=#

function dBdt!(du, biomass, MP::ModelParameters, t)

    for i in 1:length(biomass)
        biomass[i] = biomass[i] <= 0 ? 0.0 : biomass[i]
    end

    FW = MP.FoodWeb
    BR = MP.BioRates
    E = MP.Environment
    FR = MP.FunctionalResponse

    prod_growth = basalgrowth(biomass, FW, BR, E)
    cons_gain, cons_loss = consumption(biomass, FW, BR, FR, E)
    metab_loss = metaboliclosses(biomass, BR)

    dbdt = prod_growth .+ cons_gain .- cons_loss .- metab_loss
    for i in eachindex(dbdt)
        du[i] = dbdt[i] #can't return du directly, have to have 2 different objects dbdt and du for some reason... 
    end 
    
    return dbdt
end

