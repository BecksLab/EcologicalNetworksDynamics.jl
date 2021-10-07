#=
Productivity
=#

function basalgrowth(biomass, FW::FoodWeb, BR::BioRates, E::Environment)
    idp = _idproducers(FW.A)
    G = (1 .- biomass ./ E.K) .* idp
    return BR.r .* G .* biomass 
end