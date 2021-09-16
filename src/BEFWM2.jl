module BEFWM2

#dependencies
using EcologicalNetworks
using SparseArrays

# Types
include(joinpath(".", "types/declaration.jl"))
include(joinpath(".", "types/typedisplay.jl"))
include(joinpath(".", "inputs/foodwebs.jl"))
export FoodWeb

end 
