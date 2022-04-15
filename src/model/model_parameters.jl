#=
Model parameters
=#

"""
    modelparameters(FW::FoodWeb)

Generates the parameters needed to run the bio-energetic food web model. If default values are used, the parameters are as presented in Brose et al., 2006.
"""
function ModelParameters(
    FoodWeb::FoodWeb;
    BioRates::BioRates=BioRates(foodweb),
    Environment::Environment=Environment(foodweb),
    FunctionalResponse::FunctionalResponse=BioenergeticResponse(foodweb)
)

    ModelParameters(FoodWeb, BioRates, Environment, FunctionalResponse)
end
