using Documenter
using BEFWM2
using Test
using SparseArrays
using Random
using EcologicalNetworks
using JuliaFormatter

# Set and print seed
seed = sample(1:100000)
Random.seed!(seed)
@info "Seed set to $seed."

# Run doctests first
DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive = true)
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
    "model/test-effect_nti.jl",
    "model/test-model_parameters.jl",
    "model/test-consumption.jl",
    "model/test-simulate.jl",
    "measures/test-functioning.jl",
    "measures/test-utils.jl",
]

# Set up text formatting
highlight = "\033[7m"
bold = "\033[1m"
green = "\033[32m"
reset = "\033[0m"

no_break = true
for test in test_files
    println("$(highlight)$(test)$(reset)")
    global no_break = false
    include(test) # if a test fails, the loop is broken
    global no_break = true
    println("$(bold)$(green)PASSED$(reset)")
    println("------------------------------------------")
end

if no_break
    @info "Checking source code formatting.."
    exclude = ["CONTRIBUTING.md"] #  Not formatted according to JuliaFormatter.
    for (folder, _, files) in walkdir("..")
        for file in files
            if file in exclude
                continue
            end
            if !any(endswith(file, ext) for ext in [".jl", ".md", ".jmd", ".qmd"])
                continue
            end
            path = joinpath(folder, file)
            println(path)
            if !format(path; overwrite = false, format_markdown = true)
                @warn "Source code in $path is not formatted according \
                to the project style defined in ../.JuliaFormatter.toml. \
                Consider formatting it using your editor's autoformatter or with \
                `using JuliaFormatter; format(\"path/to/BEFWM2\", format_markdown=true)` \
                run from your usual sandbox/developing environment."
            end
        end
    end
end
