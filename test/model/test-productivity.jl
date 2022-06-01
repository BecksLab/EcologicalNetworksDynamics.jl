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
    K, r = p.environment.K, p.biorates.r
    B = [1, 1, 1]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], foodweb) == 0
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], foodweb) == 0
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], foodweb) == 0
    B = [0.5, 0.5, 0.5]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], foodweb) == 0.25
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], foodweb) == 0.25
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], foodweb) == 0
    p = ModelParameters(foodweb, biorates=BioRates(foodweb, r=2))
    K, r = p.environment.K, p.biorates.r
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], foodweb) == 0.5
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], foodweb) == 0.5
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], foodweb) == 0
end
