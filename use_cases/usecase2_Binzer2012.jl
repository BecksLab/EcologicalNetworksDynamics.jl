#=
Use case 2: Reproducing [Binzer et. al., 2012](https://royalsocietypublishing.org/doi/10.1098/rstb.2012.0230)) (fig. 2)
=#

using BEFWM2
using EcologicalNetworks
using DataFrames

#= STEP 1: Generate variation in temperature in three species food chain
temperature gradient 0-40C

=#
T_gradient = 273.5 .+ [0.0:1.0:40.0;] # temperature in Kelvin
A = [0 0 0; 1 0 0; 0 1 0] # tri trophic food chain
foodweb = FoodWeb(A)
foodweb.metabolic_class = ["producer", "invertebrate", "invertebrate"]



