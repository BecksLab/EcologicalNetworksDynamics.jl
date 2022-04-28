@testset "Logistic growth" begin
    # Intern method
    B, r, K = 1, 1, nothing
    @test BEFWM2.logisticgrowth(B, r, K) == 0 # K is nothing, growth is null
    B, r, K = 1, 0, 1
    @test BEFWM2.logisticgrowth(B, r, K) == 0 # r is null, growth is null
    B, r, K = 0, 1, 1
    @test BEFWM2.logisticgrowth(B, r, K) == 0 # B is null, growth is null
    B, r, K = 2, 1, 2
    @test BEFWM2.logisticgrowth(B, r, K) == 0 # B = K, growth is null
    @test BEFWM2.logisticgrowth.(0.5, 1, 1) == 0.5 * 1 * (1 - 0.5 / 1)

    # Extern method
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers
    p = ModelParameters(foodweb)
    B = [1, 1, 1]
    @test BEFWM2.logisticgrowth(1, B, p) == 0
    @test BEFWM2.logisticgrowth(2, B, p) == 0
    @test BEFWM2.logisticgrowth(3, B, p) == 0
    B = [0.5, 0.5, 0.5]
    @test BEFWM2.logisticgrowth(1, B, p) == 0.25
    @test BEFWM2.logisticgrowth(2, B, p) == 0.25
    @test BEFWM2.logisticgrowth(3, B, p) == 0
    p = ModelParameters(foodweb, biorates=BioRates(foodweb, r=2))
    @test BEFWM2.logisticgrowth(1, B, p) == 0.5
    @test BEFWM2.logisticgrowth(2, B, p) == 0.5
    @test BEFWM2.logisticgrowth(3, B, p) == 0
end
