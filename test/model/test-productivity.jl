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

    # Extern method without facilitation and with intracompetition only
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers
    S = BEFWM2.richness(foodweb)
    p = ModelParameters(
        foodweb;
        producer_competition = ProducerCompetition(foodweb; αii = 1.0, αij = 0.0),
    )
    K, r, α = p.environment.K, p.biorates.r, p.producer_competition.α

    mat_expected_growth = [0 0 0; 0.25 0.25 0]
    for (i, B) in enumerate(fill.([1, 0.5], S)) # ~ [[1, 1, 1], [0.5, 0.5, 0.5]]
        for (sp, expected_growth) in enumerate(mat_expected_growth[i, :])
            @test BEFWM2.logisticgrowth(sp, B, r[sp], K[sp], foodweb) ==
                  BEFWM2.logisticgrowth(sp, B, r[sp], K[sp], sum(α[i, :] .* B), foodweb) ==
                  expected_growth
        end
    end

    p = ModelParameters(foodweb; biorates = BioRates(foodweb; r = 2))
    K, r, α = p.environment.K, p.biorates.r, p.producer_competition.α
    B = [0.5, 0.5, 0.5]
    expected_growth = [0.5, 0.5, 0]
    for i in 1:3
        @test BEFWM2.logisticgrowth(i, B, r[i], K[i], foodweb) ==
              BEFWM2.logisticgrowth(i, B, r[i], K[i], sum(α[i, :] .* B), foodweb) ==
              expected_growth[i]
    end

    # Extern method with intra and intercompetition
    p = ModelParameters(
        foodweb;
        producer_competition = ProducerCompetition(foodweb; αii = 1.0, αij = 1.0),
    )
    K, r, α = p.environment.K, p.biorates.r, p.producer_competition.α
    B = [0.5, 0.5, 0.5]
    for i in 1:3
        # It is like each producer had a density of one (look the "B * 2" in the
        # left call of the function)
        @test BEFWM2.logisticgrowth(i, B * 2, r[i], K[i], foodweb) ==
              BEFWM2.logisticgrowth(i, B, r[i], K[i], sum(α[i, :] .* B), foodweb) ==
              0
    end

    # Test producer competition
    # 1 & 2 producer; 3 consumer
    A = [0 0 0; 0 0 0; 0 0 1]
    foodweb = FoodWeb(A; quiet = true)
    env = Environment(foodweb; K = 1)
    rates = BioRates(foodweb; d = 0)
    # K = 1, intercompetition
    p = ModelParameters(
        foodweb;
        producer_competition = ProducerCompetition(foodweb; αii = 1.0, αij = 1.0),
        biorates = rates,
        environment = env,
    )
    @test simulates(p, [0.5, 0.5, 0.5])[1:2, end] == [0.5, 0.5]

    p_inter_only = ModelParameters(
        foodweb;
        producer_competition = ProducerCompetition(foodweb; αii = 0.0, αij = 1.0),
        biorates = rates,
        environment = env,
    )
    s_inter_only = simulates(p_inter_only, [0.5, 0.5, 0.5])
    p_intra_only = ModelParameters(
        foodweb;
        producer_competition = ProducerCompetition(foodweb; αii = 1.0, αij = 0.0),
        biorates = rates,
        environment = env,
    )
    s_intra_only = simulates(p_intra_only, [0.5, 0.5, 0.5])
    @test s_inter_only[1:2, end] == s_intra_only[1:2, end] ≈ [1.0, 1.0]

    # Extern method with facilitation
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers
    multiplex_network = MultiplexNetwork(foodweb; C_facilitation = 1.0)
    # Facilitation to 0 <=> the growth is unchanged (compared to above section)
    multiplex_network.layers[:facilitation].intensity = 0.0
    response = ClassicResponse(multiplex_network) # avoid warning
    p = ModelParameters(multiplex_network; functional_response = response)
    K, r = p.environment.K, p.biorates.r
    B = [1, 1, 1]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    B = [0.5, 0.5, 0.5]
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.25
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.25
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    rates = BioRates(multiplex_network; r = 2)
    p = ModelParameters(multiplex_network; functional_response = response, biorates = rates)
    K, r = p.environment.K, p.biorates.r
    @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.5
    @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.5
    @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    # Facilitation > 0 <=> the growth is changed (compared to above section)
    for f0 in [1.0, 2.0, 5.0, 10.0]
        multiplex_network.layers[:facilitation].intensity = f0
        p = ModelParameters(multiplex_network; functional_response = response)
        K, r = p.environment.K, p.biorates.r
        B = [1, 1, 1]
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
        B = [0.5, 0.5, 0.5]
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.25 * (1 + f0)
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.25 * (1 + f0)
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
        rates = BioRates(multiplex_network; r = 2)
        p = ModelParameters(
            multiplex_network;
            functional_response = response,
            biorates = rates,
        )
        K, r = p.environment.K, p.biorates.r
        @test BEFWM2.logisticgrowth(1, B, r[1], K[1], multiplex_network) == 0.5 * (1 + f0)
        @test BEFWM2.logisticgrowth(2, B, r[2], K[2], multiplex_network) == 0.5 * (1 + f0)
        @test BEFWM2.logisticgrowth(3, B, r[3], K[3], multiplex_network) == 0
    end
end
