using Documenter
using BEFWM2
using Test
using SparseArrays
using Random
using EcologicalNetworks

# Set and print seed
seed = sample(1:100000)
Random.seed!(seed)
@info "Seed set to $seed."

# Run doctests first
DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive=true)
doctest(BEFWM2)
println("------------------------------------------")

# Run test files
test_files = [
    "test-utils.jl",
    "inputs/test-biological_rates.jl",
    "inputs/test-functional_response.jl",
    "inputs/test-environment.jl",
    "inputs/test-nontrophic_interactions.jl",
    "model/test-productivity.jl",
    "model/test-metabolic_loss.jl",
    "model/test-model_parameters.jl",
    "model/test-consumption.jl",
    "model/test-simulate.jl"
]

for test in test_files
    println("\033[7m$(test)\033[0m")
    include(test)
    println("\033[1m\033[32mPASSED\033[0m")
    println("------------------------------------------")
end
