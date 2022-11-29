using SyntaxTree
using Logging #  TODO: remove once warnings are removed from `generate_dbdt`.

# Wrap 'simulate' in a routine testing identity between
# generic simulation code and generated code.
function simulates(parms, B0; kwargs...)
    g = simulate(parms, B0; verbose = false, kwargs...)

    # Compare with raw specialized code.
    xp, data = Logging.with_logger(() -> generate_dbdt(parms, :raw), Logging.NullLogger())
    # Guard against explosive compilation times with this approach.
    if SyntaxTree.callcount(xp) <= 20_000 #  wild rule of thumb
        dbdt = eval(xp)
        s = simulate(parms, B0; diff_code_data = (dbdt, data), verbose = false, kwargs...)
        compare_generic_vs_specialized(g, s)
    end

    # Compare with compact specialized code.
    xp, data =
        Logging.with_logger(() -> generate_dbdt(parms, :compact), Logging.NullLogger())
    dbdt = eval(xp)
    s = simulate(parms, B0; diff_code_data = (dbdt, data), verbose = false, kwargs...)
    compare_generic_vs_specialized(g, s)

    g
end

function compare_generic_vs_specialized(g, s)
    @test g.retcode == s.retcode
    @test g.k ≈ s.k
    @test g.t ≈ s.t
    @test g.u ≈ s.u
end

@testset "Simulate" begin

    # Set up
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)

    # Solution converges
    solution1 = simulate(params, [0.5, 0.5])
    @test solution1.retcode == :Terminated
    solution2 = simulate(params, [0.3, 0.3]; saveat = 0.25, tmax = 10)
    @test solution2.retcode == :Success
    solution3 = simulate(params, [0.2, 0.2]; saveat = 0.5, tmax = 5)
    @test solution3.retcode == :Success

    # Initial biomass
    @test solution1.u[begin] == [0.5, 0.5]
    @test solution2.u[begin] == [0.3, 0.3]
    @test solution3.u[begin] == [0.2, 0.2]

    # Timesteps
    @test all([t ∈ Set(solution2.t) for t in (0:0.25:10)])
    @test all([t ∈ Set(solution3.t) for t in (0:0.5:5)])

    # If biomass start at 0, biomass stay at 0
    solution_null = simulate(params, [0.0, 0.0]; callback = nothing)
    @test all(hcat(solution_null.u...) .== 0)

    # Verbose - Is there a log message to inform the user of species going extinct?
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)
    @test_nowarn simulate(params, [0.5, 1e-12], verbose = false)
    log_msg =
        "Species [2] went extinct at time t = 0.1. \n" * "1 over 2 species are extinct."
    @test_logs (:info, log_msg) simulate(
        params,
        [0.5, 1e-12],
        verbose = true,
        tstops = [0.1],
    )

    # Extinction threshold
    ## Both species below extinction threshold
    solution =
        simulate(params, [1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end] == [0.0, 0.0] # both species have gone extinct
    ## One species below extinction thresold
    solution =
        simulate(params, [1, 1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
    ## Provide a vector of extinction threshold (one threshold per species)
    solution = simulate(
        params,
        [1e-5];
        extinction_threshold = [1e-6, 1e-4],
        tmax = 1,
        verbose = false,
    )
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
end
