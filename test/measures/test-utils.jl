@testset "filtering simulation" begin

    # Set up
    foodweb = FoodWeb([0 0; 0 0]; quiet = true)
    params = ModelParameters(foodweb)

    sim = simulates(params, [0, 0.5]; tmax = 20)

    @test size(EcologicalNetworksDynamics.filter_sim(sim; last = 1), 2) == 1
    @test size(EcologicalNetworksDynamics.filter_sim(sim; last = 10), 2) == 10
    @test EcologicalNetworksDynamics.filter_sim(sim; last = 10) isa Matrix
end
