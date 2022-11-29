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
    @test get_extinct_species(solution_null) == [1, 2]

    # Verbose - Is there a log message to inform the user of species going extinct?
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)
    @test_nowarn simulate(params, [0.5, 1e-12], verbose = false)
    @test get_extinct_species(simulate(params, [0.5, 1e-12]; verbose = false)) == [2]
    log_msg =
        "Species [2] went extinct at time t = 0.1. \n" * "1 over 2 species are extinct."
    @test_logs (:info, log_msg) simulate(
        params,
        [0.5, 1e-12],
        verbose = true,
        tstops = [0.1],
    )
    @test get_extinct_species(
        simulate(params, [0.5, 1e-12]; verbose = true, tstops = [0.1]),
    ) == [2]

    # Extinction threshold
    ## Both species below extinction threshold
    solution =
        simulate(params, [1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end] == [0.0, 0.0] # both species have gone extinct
    @test get_extinct_species(solution) == [1, 2]
    ## One species below extinction thresold
    solution =
        simulate(params, [1, 1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
    @test get_extinct_species(solution) == [2]
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
    @test get_extinct_species(solution) == [2]
end

# Test inspired by this issue:
# https://discourse.julialang.org/t/zombies-in-biological-ode-why-is-my-solver-not-sticking-to-zero/90409
@testset "No zombies, extinction are handled correctly." begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0])
    biorates = BioRates(foodweb; y = [0, 7.992, 8])
    params = ModelParameters(foodweb; biorates = biorates)
    B0 = [0.5, 0.5, 0.5]
    sol = simulate(params, B0; callback = ExtinctionCallback(1e-5, true), tmax = 300_000)
    @test get_extinct_species(sol) == [2]
    sol2 = sol[2, :] # trajectory of species 2 biomass
    idx_cb_triggered = findall(x -> 0 < x < 1e-5, sol2)
    @test length(idx_cb_triggered) == 1 # cb triggered only once (no zombies)
    idx_cb_triggered = idx_cb_triggered[1]
    # When callback is triggered previous and next state are saved
    # to identify unambiguously the discontinuity.
    # Then we have two time steps at t_discontinuity:
    # 1. 0 < B_going_extinct <= extinction_threshold (before the callback)
    # 2. B_going_extinct = 0 (after the callback)
    @test sol.t[idx_cb_triggered] == sol.t[idx_cb_triggered+1]
    @test all(sol2 .>= 0) # no anti-biomass
end
