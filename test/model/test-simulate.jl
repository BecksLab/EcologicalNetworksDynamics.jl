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
end
