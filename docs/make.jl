push!(LOAD_PATH,"../src/")

import Pkg
Pkg.activate(".")
using Documenter
using BEFWM2

makedocs(sitename="BioEnergeticFoodWebs")

deploydocs(
    repo = "github.com/evadelmas/BEFWM2.jl.git",
)