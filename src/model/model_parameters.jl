#=
Model parameters
=#

"""
    modelparameters(FW::FoodWeb)

Generates the parameters needed to run the bio-energetic food web model. If default values are used, the parameters are as presented in Brose et al., 2006.
"""
function ModelParameters(FW::FoodWeb
    ; BR::Union{Nothing, BioRates}=nothing
    , E::Union{Nothing, Environment}=nothing
    , FR::Union{Nothing, FunctionalResponse}=nothing)

    BR = isnothing(BR) && BioRates(FW)
    E = isnothing(E) && Environment(FW)
    FR = isnothing(FR) && originalFR(FW)

    return ModelParameters(FW, BR, E, FR)
end