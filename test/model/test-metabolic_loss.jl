@testset "Metabolic loss" begin
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0])
    p = ModelParameters(foodweb)
    B = [1, 1, 1]
    @test BEFWM2.metabolic_loss(1, B, p) == 0 # no loss for producers
    @test BEFWM2.metabolic_loss(2, B, p) == 0 # no loss for producers
    @test BEFWM2.metabolic_loss(3, B, p) == 0.314 # loss for consumers...
    B = [2, 2, 2]
    @test BEFWM2.metabolic_loss(3, B, p) == 2 * 0.314 # ...increase with biomass
end

@testset "Effect of competition on net growth rate" begin
    foodweb = FoodWeb([0 0; 0 0]) # 2 producers
    multiplex_network = MultiplexNetwork(foodweb, C_competition=1.0)
    for c0 in [0.0, 1.0, 2.0, 5.0, 10.0]
        multiplex_network.nontrophic_intensity.c0 = c0
        B = [0.1, 0.2]
        @test BEFWM2.competition_factor(1, B, multiplex_network) == max(1 - 0.2 * c0, 0)
        @test BEFWM2.competition_factor(2, B, multiplex_network) == max(1 - 0.1 * c0, 0)
    end
end
