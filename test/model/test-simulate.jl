@testset "Simulate" begin

    # Set up
    foodweb = FoodWeb([0 0; 1 0])
    params = ModelParameters(foodweb)

    # Solution converges
    solution1 = simulate(params, [0.5, 0.5])
    @test solution1.retcode == :Success
    solution2 = simulate(params, [0.3, 0.3], stop=1000)
    @test solution2.retcode == :Success
    solution3 = simulate(params, [0.0, 0.0], δt=0.5)
    @test solution3.retcode == :Success

    # Initial biomass
    @test solution1.u[begin] == [0.5, 0.5]
    @test solution2.u[begin] == [0.3, 0.3]
    @test solution3.u[begin] == [0.0, 0.0]

    # Timesteps
    @test solution1.t == collect(0:0.25:500)
    @test solution2.t == collect(0:0.25:1000)
    @test solution3.t == collect(0:0.5:500)

    # If biomass start at 0, biomass stay at 0
    @test all(hcat(solution3.u...) .== 0)
end
