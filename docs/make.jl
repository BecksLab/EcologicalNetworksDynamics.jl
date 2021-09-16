push!(LOAD_PATH,"../src/")

import Pkg
Pkg.activate(".")
using Documenter
using BEFWM2

makedocs(sitename="BioEnergeticFoodWebs")