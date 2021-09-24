#=
Core functions of the model
=#

function dBdt(derivative, biomass, MP::ModelParameters, t)

    FW = MP.FoodWeb
    BR = MP.BioRates
    E = MP.Environment
    FR = MP.FunctionalResponse

    prod_growth = basalgrowth(biomass, BR, E)
    cons_gain, cons_loss = consumption(biomass, FW, BR, FR, E)
    metab_loss = metaboliclosses(biomass, BR)

    derivative = prod_growth .+ cons_gain .- cons_loss .- metab_loss
    
    return ΔB
end

