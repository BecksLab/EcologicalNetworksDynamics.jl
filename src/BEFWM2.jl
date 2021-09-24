module BEFWM2

#dependencies
using EcologicalNetworks
using SparseArrays
using DiffEqBase

# Types
include(joinpath(".", "types/declaration.jl"))
include(joinpath(".", "types/typedisplay.jl"))

include(joinpath(".", "inputs/foodwebs.jl"))
include(joinpath(".", "inputs/functional_response.jl"))
include(joinpath(".", "inputs/biological_rates.jl"))
include(joinpath(".", "inputs/environment.jl"))

include(joinpath(".", "model/productivity.jl"))
include(joinpath(".", "model/consumption.jl"))
include(joinpath(".", "model/metaboliclosses.jl"))
include(joinpath(".", "model/model_parameters.jl"))
include(joinpath(".", "model/dbdt.jl"))
include(joinpath(".", "model/simulate.jl"))

include(joinpath(".", "measures/structure.jl"))


export FoodWeb, ModelParameters, FunctionalResponse, BioRates, Environment
export homogeneous_preference, originalFR
export allometricgrowth, allometricmetabolism, allometricmaxconsumption
export simulate 

end 
