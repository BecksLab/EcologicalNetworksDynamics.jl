@testset "filtering simulation" begin

    # Set up
    foodweb = FoodWeb([0 0; 0 0])
    params = ModelParameters(foodweb)

    sim = simulates(params, [0, 0.5]; tmax = 20)

    @test size(BEFWM2.filter_sim(sim; last = 1), 2) == 1
    @test size(BEFWM2.filter_sim(sim; last = 10), 2) == 10
    @test BEFWM2.filter_sim(sim; last = 10) isa Matrix
end
