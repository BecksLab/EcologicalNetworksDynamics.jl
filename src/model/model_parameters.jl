#=
Model parameters
=#

"""
    modelparameters(FW::FoodWeb)

Generates the parameters needed to run the bio-energetic food web model. If default values are used, the parameters are as presented in Brose et al., 2006.
"""
function ModelParameters(FW::FoodWeb
    ; BR::Union{Nothing,BioRates}=nothing, E::Union{Nothing,Environment}=nothing, FR::Union{Nothing,FunctionalResponse}=nothing)

    if isnothing(BR)
        BR = BioRates(FW)
    end

    if isnothing(E)
        E = Environment(FW)
    end

    if isnothing(FR)
        FR = BioEnergeticFunctionalResponse(FW)
    end

    return ModelParameters(FW, BR, E, FR)
end
