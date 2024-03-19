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
        callback = ExtinctionCallback(1e-5, params, true),
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

# Ensure that when an species already extinct species comeback to life (aka a zombie)
# when using an implicit solver, that no @info message are shown.
# For more information about zombies see these issues:
# https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues/65
# https://discourse.julialang.org/t/zombies-in-biological-ode-why-is-my-solver-not-sticking-to-zero/90409
@testset "Do not print zombies." begin
    Random.seed!(12) # Set a seed for reproducibility.
    S = 30
    fw = FoodWeb(niche_model, S; C = 0.1)
    functional_response = ClassicResponse(fw)
    params = ModelParameters(fw; functional_response)
    logger = TestLogger()
    with_logger(logger) do
        simulates(params, rand(S); tmax = 1_000_000, verbose = true)
    end
    # Test that the `simulate` @info messages never contain empty vector of new extinct
    # species.
    # Otherwise, this means that a zombies has appeared and triggered the @info message.
    @test length(logger.logs) > 0
    for log in logger.logs
        log.level == Logging.Info && @test !(occursin("[]", log.message))
    end
end
