#=
Use case 2: Reproducing [Binzer et. al., 2016](https://doi.org/10.1111/gcb.13086)) (fig. 2)
=#

using BEFWM2
using EcologicalNetworks
using DataFrames

#= STEP 1: Generate variation in temperature and communities structure
temperature gradient 0-40C
and log10 consumer-resource body-mass ratio between -1 and 4 in steps of 1
fixed species richness and connectance
=#
T_gradient = 273.5 .+ [0.0:1.0:40.0;] # temperature in Kelvin
Z_levels = 10 .^ [-1.0:1:4;] # average predator-prey mass ratio
s = 30 # fixed
c = 0.1 # fixed



