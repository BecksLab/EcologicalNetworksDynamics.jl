module BEFWM2

#dependencies
using EcologicalNetworks
using SparseArrays

# Types
include(joinpath(".", "types/declaration.jl"))
include(joinpath(".", "types/typedisplay.jl"))
include(joinpath(".", "inputs/foodwebs.jl"))
include(joinpath(".", "measures/structure.jl"))
include(joinpath(".", "inputs/functional_response.jl"))
include(joinpath(".", "inputs/biological_rates.jl"))

export FoodWeb, BEFWMParameters, FunctionalResponse
export homogeneous_preference, originalFR
export allometricgrowth, allometricmetabolism, allometricmaxconsumption

end 
