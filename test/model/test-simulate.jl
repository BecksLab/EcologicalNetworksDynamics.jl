@testset "Simulate" begin

    # Set up
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)

    # Solution converges
    solution1 = simulate(params, [0.5, 0.5])
    @test solution1.retcode == :Terminated
    solution2 = simulate(params, [0.3, 0.3], tmax=10)
    @test solution2.retcode == :Success
    solution3 = simulate(params, [0.2, 0.2], δt=0.5, tmax=10)
    @test solution3.retcode == :Success

    # Initial biomass
    @test solution1.u[begin] == [0.5, 0.5]
    @test solution2.u[begin] == [0.3, 0.3]
    @test solution3.u[begin] == [0.2, 0.2]

    # Timesteps
    @test all([t ∈ Set(solution2.t) for t in (0:0.25:10)])
    @test all([t ∈ Set(solution3.t) for t in (0:0.5:10)])

    # If biomass start at 0, biomass stay at 0
    solution_null = simulate(params, [0.0, 0.0])
    @test all(hcat(solution_null.u...) .== 0)

    # Verbose - Is there a log message to inform the user of species going extinct?
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)
    @test_nowarn simulate(params, [0.5, 1e-12], verbose=false)
    log_msg = "Species [2] is exinct. t=0.12316364776188903"
    @test_warn (log_msg) simulate(params, [0.5, 1e-12], verbose=true)

    # Extinction threshold
    ## Both species below extinction threshold
    solution = simulate(params, [1e-2], extinction_threshold=0.1, tmax=1) # B0 < extinction
    @test solution.u[end] == [0.0, 0.0] # both species have gone extinct
    ## One species below extinction thresold
    solution = simulate(params, [1, 1e-2], extinction_threshold=0.1, tmax=1)
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
    ## Provide a vector of extinction threshold (one threshold per species)
    solution = simulate(params, [0.1], extinction_threshold=[1e-2, 1], tmax=1)
    @test solution.u[end][2] == 0 # species 2 is extinct
    @test solution.u[end][1] > 0 # species 1 is alive
end
