using Documenter
using BEFWM2
using Test
using SparseArrays
using Random
using EcologicalNetworks
using JuliaFormatter
using SyntaxTree
using Logging #  TODO: remove once warnings are removed from `generate_dbdt`.


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
    "inputs/test-foodwebs.jl",
    "inputs/test-biological_rates.jl",
    "inputs/test-functional_response.jl",
    "inputs/test-environment.jl",
    "inputs/test-nontrophic_interactions.jl",
    "inputs/test-producer_competition.jl",
    "inputs/test-stochasticity.jl",
    "model/test-productivity.jl",
    "model/test-metabolic_loss.jl",
    "model/test-effect_nti.jl",
    "model/test-model_parameters.jl",
    "model/test-consumption.jl",
    "model/test-simulate.jl",
    "measures/test-functioning.jl",
    "measures/test-utils.jl",
]

# Wrap 'simulate' in a routine testing identity between
# generic simulation code and generated code.
function simulates(parms, B0; compare_atol = nothing, compare_rtol = nothing, kwargs...)
    g = BEFWM2.simulate(parms, B0; verbose = false, kwargs...)

    # Compare with raw specialized code.
    xp, data = Logging.with_logger(() -> generate_dbdt(parms, :raw), Logging.NullLogger())
    # Guard against explosive compilation times with this approach.
    if SyntaxTree.callcount(xp) <= 20_000 #  wild rule of thumb
        dbdt = eval(xp)
        s = BEFWM2.simulate(
            parms,
            B0;
            diff_code_data = (dbdt, data),
            verbose = false,
            kwargs...,
        )
        compare_generic_vs_specialized(g, s, :raw, compare_atol, compare_rtol)
    end

    # Compare with compact specialized code.
    xp, data =
        Logging.with_logger(() -> generate_dbdt(parms, :compact), Logging.NullLogger())
    dbdt = eval(xp)
    s = BEFWM2.simulate(
        parms,
        B0;
        diff_code_data = (dbdt, data),
        verbose = false,
        kwargs...,
    )
    compare_generic_vs_specialized(g, s, :compact, compare_atol, compare_rtol)

    g
end

function compare_generic_vs_specialized(g, s, style, atol, rtol)
    kwargs = Dict()
    isnothing(atol) || (kwargs[:atol] = atol)
    isnothing(rtol) || (kwargs[:rtol] = rtol)
    if !(
        g.retcode == s.retcode &&
        size(g.t) == size(s.t) &&
        size(g.u) == size(s.u) &&
        isapprox(g.t, s.t; kwargs...) &&
        isapprox(g.u, s.u; kwargs...)
    )
        throw(AssertionError("Boosted simulation (:$style) \
                          appears to yield different results than regular simulation."))
    end
end

# Deactivate `simulate` so only the full version can be used in tests.
simulate(args...; kwargs...) =
    throw(AssertionError("Don't use `simulate()` in tests, use `simulates()` instead \
                          so that all simulation flavours are tested together at once."))

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
