module TestInternals

using Crayons
using EcologicalNetworksDynamics.Internals
using Logging
using Random
using SparseArrays
using Statistics
using SyntaxTree
using Test

# Set and print seed
seed = rand(1:100000)
Random.seed!(seed)
@info "Seed set to $seed."

# Run test files
test_files = [
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
    "model/test-zombies.jl",
    "model/test-nutrient_intake.jl",
    "model/test-set_temperature.jl",
    "measures/test-functioning.jl",
    "measures/test-stability.jl",
    "measures/test-structure.jl",
    "measures/test-utils.jl",
]

# Wrap 'simulate' in a routine testing identity between
# generic simulation code and generated code.
function simulates(parms, B0; compare_atol = nothing, compare_rtol = nothing, kwargs...)
    g = Internals.simulate(parms, B0; verbose = false, kwargs...)

    if is_boostable(parms, :raw)
        # Compare with raw specialized code.
        xp, data =
            Logging.with_logger(() -> generate_dbdt(parms, :raw), Logging.NullLogger())
        # Guard against explosive compilation times with this approach.
        if SyntaxTree.callcount(xp) <= 20_000 #  wild rule of thumb
            dbdt = eval(xp)
            s = Internals.simulate(
                parms,
                B0;
                diff_code_data = (dbdt, data),
                verbose = false,
                kwargs...,
            )
            compare_generic_vs_specialized(g, s, :raw, compare_atol, compare_rtol)
        end
    end

    if is_boostable(parms, :compact)
        # Compare with compact specialized code.
        xp, data =
            Logging.with_logger(() -> generate_dbdt(parms, :compact), Logging.NullLogger())
        dbdt = eval(xp)
        s = Internals.simulate(
            parms,
            B0;
            diff_code_data = (dbdt, data),
            verbose = false,
            kwargs...,
        )
        # compare_generic_vs_specialized(g, s, :compact, compare_atol, compare_rtol)
        # TODO: Iago
    end

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
highlight = crayon"negative"
bold = crayon"bold"
green = crayon"green"
reset = crayon"reset"

for test in test_files
    println("$(highlight)$(test)$(reset)")
    include(test)
    println("$(bold)$(green)PASSED$(reset)")
    println("------------------------------------------")
end

end
