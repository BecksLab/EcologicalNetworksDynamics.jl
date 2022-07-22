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

    # Extern method without facilitation
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

    # Extern method with facilitation
    multiplex_network = MultiplexNetwork(foodweb, C_facilitation=1.0)
    # Facilitation to 0 <=> the growth is unchanged (compared to above section)
    multiplex_network.layers[:facilitation].intensity = 0.0
    response = ClassicResponse(multiplex_network) # avoid warning
    p = ModelParameters(multiplex_network, functional_response=response)
    K, r = p.environment.K, p.biorates.r
    B = [1, 1, 1]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    B = [0.5, 0.5, 0.5]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.25
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.25
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    rates = BioRates(multiplex_network, r=2)
    p = ModelParameters(multiplex_network, functional_response=response, biorates=rates)
    K, r = p.environment.K, p.biorates.r
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.5
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.5
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    # Facilitation > 0 <=> the growth is changed (compared to above section)
    for f0 in [1.0, 2.0, 5.0, 10.0]
        multiplex_network.layers[:facilitation].intensity = f0
        p = ModelParameters(multiplex_network, functional_response=response)
        K, r = p.environment.K, p.biorates.r
        B = [1, 1, 1]
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
        B = [0.5, 0.5, 0.5]
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.25 * (1 + f0)
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.25 * (1 + f0)
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
        rates = BioRates(multiplex_network, r=2)
        p = ModelParameters(multiplex_network, functional_response=response, biorates=rates)
        K, r = p.environment.K, p.biorates.r
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.5 * (1 + f0)
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.5 * (1 + f0)
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    end
end
