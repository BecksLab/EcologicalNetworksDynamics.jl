using Documenter
using BEFWM2
using Test
using SparseArrays

# Run doctests first.
DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive=true)
doctest(BEFWM2)

include("inputs/test-biological_rates.jl")
include("inputs/test-functional_response.jl")
include("model/test-productivity.jl")
include("model/test-metabolic_loss.jl")
include("model/test-model_parameters.jl")
