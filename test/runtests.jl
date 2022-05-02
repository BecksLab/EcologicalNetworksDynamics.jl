using Documenter
using BEFWM2
using Test
using SparseArrays
using Random
using EcologicalNetworks

# Set and print seed
seed = sample(1:100000)
Random.seed!(seed)
println("Seed set to $seed.")

# Run doctests first.
DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive=true)
doctest(BEFWM2)

include("test-utils.jl")
include("inputs/test-biological_rates.jl")
include("inputs/test-functional_response.jl")
include("inputs/test-environment.jl")
include("inputs/test-nontrophic_interactions.jl")
include("model/test-productivity.jl")
include("model/test-metabolic_loss.jl")
include("model/test-model_parameters.jl")
include("model/test-consumption.jl")
include("model/test-simulate.jl")
