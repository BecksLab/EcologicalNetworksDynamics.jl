@testset "Simulate" begin

    # Set up
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb; biorates = BioRates(foodweb; d = 0))

    # Solution converges
    solution1 = simulates(params, [0.5, 0.5]; verbose = false)
    @test solution1.retcode == :Terminated
    solution2 = simulates(params, [0.3, 0.3]; saveat = 0.25, tmax = 10, verbose = false)
    @test solution2.retcode == :Success
    solution3 = simulates(params, [0.2, 0.2]; saveat = 0.5, tmax = 5, verbose = false)
    @test solution3.retcode == :Success


    # Initial biomass
    @test solution1.u[begin] == [0.5, 0.5]
    @test solution2.u[begin] == [0.3, 0.3]
    @test solution3.u[begin] == [0.2, 0.2]

    # Timesteps
    @test all([t ∈ Set(solution2.t) for t in (0:0.25:10)])
    @test all([t ∈ Set(solution3.t) for t in (0:0.5:5)])

    # If biomass start at 0, biomass stay at 0
    solution_null = simulates(params, [0.0, 0.0]; callback = nothing)
    @test all(hcat(solution_null.u...) .== 0)
    @test keys(get_extinct_species(solution_null)) == Set([1, 2])


    # Check against negative initial biomass values.
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)
    @test_throws ArgumentError simulates(params, [-1], verbose = false)
    @test_throws ArgumentError simulates(params, [0.1, -1], verbose = false)
    @test_nowarn simulates(params, [1, 0], verbose = false)


    # Verbose - Is there a log message to inform the user of species going extinct?
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb; biorates = BioRates(foodweb; d = 0))
    @test_nowarn simulates(params, [0.5, 1e-12], verbose = false)
    @test keys(get_extinct_species(simulates(params, [0.5, 1e-12]; verbose = false))) ==
          Set([2])
    log_msg =
        "Species [2] went extinct at time t = 0.1. \n" * "1 over 2 species are extinct."
    @test_logs (:info, log_msg) (:info, log_msg) (:info, log_msg) simulates(
        params,
        [0.5, 1e-12],
        verbose = true,
        tstops = [0.1],
        compare_rtol = 1e-6,
    )
    @test keys(
        get_extinct_species(
            simulates(params, [0.5, 1e-12]; verbose = true, tstops = [0.1]),
        ),
    ) == Set([2])


    # Extinction threshold
    ## Both species below extinction threshold
    solution =
        simulates(params, [1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end] == [0.0, 0.0] # both species have gone extinct
    @test keys(get_extinct_species(solution)) == Set([1, 2])
    ## One species below extinction thresold
    solution =
        simulates(params, [1, 1e-6]; extinction_threshold = 1e-5, tmax = 1, verbose = false)
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
    @test keys(get_extinct_species(solution)) == Set([2])
    ## Provide a vector of extinction threshold (one threshold per species)
    solution = simulates(
        params,
        [1e-5];
        extinction_threshold = [1e-6, 1e-4],
        tmax = 1,
        verbose = false,
    )
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
    @test keys(get_extinct_species(solution)) == Set([2])
    ## Error if extinction threshold is not a Number or an AbstractVector
    @test_throws TypeError simulates(params, [1]; extinction_threshold = Set([1e-5]))

    # Does simulate still run with stochasticity?
    foodweb = FoodWeb([0 0; 1 0])
    stochasticity = AddStochasticity(
    foodweb,
    BioRates(foodweb);
    addstochasticity = true,
    wherestochasticity = "producers",
    nstochasticity = "all",
    σe = 0.5,
    θ = 0.5,
    )
    params = ModelParameters(foodweb, stochasticity = stochasticity)
    # TODO: use `simulates` to check against boosted versions when available.
    solution = BEFWM2.simulate(params, [0.5, 0.5])
    @test solution.retcode == :Success
end

# Test inspired by this issue:
# https://discourse.julialang.org/t/zombies-in-biological-ode-why-is-my-solver-not-sticking-to-zero/90409
@testset "No zombies, extinction are handled correctly." begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0])
    biorates = BioRates(foodweb; y = [0, 7.992, 8])
    params = ModelParameters(foodweb; biorates = biorates)
    B0 = [0.5, 0.5, 0.5]
    sol = simulates(
        params,
        B0;
        callback = ExtinctionCallback(1e-5, true),
        tmax = 300_000,
        verbose = false,
        compare_rtol = 1e-6,
    )
    @test keys(get_extinct_species(sol)) == Set([2])
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

@testset "Equivalence natural mortality and metabolic demand" begin
    foodweb = FoodWeb([0 0; 1 0]; Z = 50)
    F = ClassicResponse(foodweb; aᵣ = 1.0)
    params_xd = ModelParameters(foodweb; functional_response = F)
    total_loss = params_xd.biorates.x .+ params_xd.biorates.d
    biorates_x = BioRates(foodweb; x = total_loss, d = 0)
    biorates_d = BioRates(foodweb; d = total_loss, x = 0)
    params_x = ModelParameters(foodweb; functional_response = F, biorates = biorates_x)
    params_d = ModelParameters(foodweb; functional_response = F, biorates = biorates_d)
    out_xd = simulates(params_xd, [1])
    out_d = simulates(params_d, [1])
    out_x = simulates(params_x, [1])
    @test out_xd.u[end] ≈ out_x.u[end] ≈ out_d.u[end]
end
