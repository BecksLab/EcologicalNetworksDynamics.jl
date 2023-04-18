using Documenter
using EcologicalNetworksDynamics
using Test
using SparseArrays
using Random
using JuliaFormatter
using SyntaxTree
using Logging #  TODO: remove once warnings are removed from `generate_dbdt`.
using Statistics


# Set and print seed
seed = rand(1:100000)
Random.seed!(seed)
@info "Seed set to $seed."

# Run doctests first
DocMeta.setdocmeta!(
    EcologicalNetworksDynamics,
    :DocTestSetup,
    :(using EcologicalNetworksDynamics);
    recursive = true,
)
doctest(EcologicalNetworksDynamics)
println("------------------------------------------")

# Run test files
test_files = [
    "test-basic-pipeline.jl",
    "test-utils.jl",
    "inputs/test-foodwebs.jl",
    "inputs/test-biological_rates.jl",
    "inputs/test-functional_response.jl",
    "inputs/test-environment.jl",
    "inputs/test-nontrophic_interactions.jl",
    "inputs/test-producer_competition.jl",
    "inputs/test-temperature_dependent_rates.jl",
    "model/test-productivity.jl",
    "model/test-metabolic_loss.jl",
    "model/test-effect_nti.jl",
    "model/test-model_parameters.jl",
    "model/test-consumption.jl",
    "model/test-simulate.jl",
    "model/test-set_temperature.jl",
    "measures/test-functioning.jl",
    "measures/test-stability.jl",
    "measures/test-structure.jl",
    "measures/test-utils.jl",
]

# Wrap 'simulate' in a routine testing identity between
# generic simulation code and generated code.
function simulates(parms, B0; compare_atol = nothing, compare_rtol = nothing, kwargs...)
    g = EcologicalNetworksDynamics.simulate(parms, B0; verbose = false, kwargs...)

    # Compare with raw specialized code.
    xp, data = Logging.with_logger(() -> generate_dbdt(parms, :raw), Logging.NullLogger())
    # Guard against explosive compilation times with this approach.
    if SyntaxTree.callcount(xp) <= 20_000 #  wild rule of thumb
        dbdt = eval(xp)
        s = EcologicalNetworksDynamics.simulate(
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
    s = EcologicalNetworksDynamics.simulate(
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
    exclude = [
        "CONTRIBUTING.md", # Not formatted according to JuliaFormatter.
        "docs/src/man/boost.md", # Wait on https://github.com/JuliaDocs/Documenter.jl/issues/2025 or the end of boost warnings.
    ]
    for (folder, _, files) in walkdir("..")
        for file in files
            path = joinpath(folder, file)
            display_path = joinpath(splitpath(path)[2:end]...)
            if display_path in exclude
                continue
            end
            if !any(endswith(file, ext) for ext in [".jl", ".md", ".jmd", ".qmd"])
                continue
            end
            println(display_path)
            if !format(path; overwrite = false, format_markdown = true)
                config_path =
                    joinpath(basename(dirname(abspath(".."))), ".JuliaFormatter.toml")
                dev_path = escape_string(abspath(path))
                @warn "Source code in $file is not formatted according \
                to the project style defined in $config_path. \
                Consider formatting it using your editor's autoformatter or with:\n\
                    julia> using JuliaFormatter;\n\
                    julia> format(\"$dev_path\", format_markdown=true)\n"
            end
        end
    end
end
