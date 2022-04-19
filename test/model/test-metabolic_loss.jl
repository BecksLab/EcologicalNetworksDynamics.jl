@testset "Metabolic loss" begin
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0])
    p = ModelParameters(foodweb)
    B = [1, 1, 1]
    @test BEFWM2.metabolic_loss(B, p.BioRates) == [0, 0, 0.314]
    B = [2, 2, 2]
    @test BEFWM2.metabolic_loss(B, p.BioRates) == [0, 0, 2 * 0.314]
end
