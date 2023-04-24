@testset "Logistic growth" begin
    # Intern method
    B, r, K, s = 1, 1, nothing, 0
    @test EcologicalNetworksDynamics.logisticgrowth(B, r, K, s) == 0 # K is nothing, growth is null
    B, r, K, s = 1, 0, 1, 0
    @test EcologicalNetworksDynamics.logisticgrowth(B, r, K, s) == 0 # r is null, growth is null
    B, r, K, s = 0, 1, 1, 0
    @test EcologicalNetworksDynamics.logisticgrowth(B, r, K, s) == 0 # B is null, growth is null
    B, r, K, s = 2, 1, 2, 2
    @test EcologicalNetworksDynamics.logisticgrowth(B, r, K, s) == 0 # B = K, growth is null
    @test EcologicalNetworksDynamics.logisticgrowth.(0.5, 1, 1, 0.5) == 0.5 * 1 * (1 - 0.5 / 1)

    # Extern method without facilitation and with intracompetition only
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers
    S = EcologicalNetworksDynamics.richness(foodweb)
    p = ModelParameters(
        foodweb;
        producer_growth = LogisticGrowth(foodweb; αii = 1.0, αij = 0.0),
    )
    K, r, α = p.environment.K, p.biorates.r, p.producer_growth.α

    mat_expected_growth = [0 0 0; 0.25 0.25 0]
    for (i, B) in enumerate(fill.([1, 0.5], S)) # ~ [[1, 1, 1], [0.5, 0.5, 0.5]]
        for (sp, expected_growth) in enumerate(mat_expected_growth[i, :])
            println((i, sp))
            prodgrowth = LogisticGrowth(foodweb)
            prodgrowth_α = LogisticGrowth(foodweb, α = α)
            @test prodgrowth(sp, B, r, foodweb, nothing) == 
                prodgrowth_α(sp, B, r, foodweb, nothing) == 
                expected_growth
        end
    end

    p = ModelParameters(foodweb; biorates = BioRates(foodweb; r = 2))
    K, r, α = p.environment.K, p.biorates.r, p.producer_growth.α
    B = [0.5, 0.5, 0.5]
    expected_growth = [0.5, 0.5, 0]
    for i in 1:3
        prodgrowth = LogisticGrowth(foodweb)
        prodgrowth_α = LogisticGrowth(foodweb, α = α)
        @test prodgrowth(i, B, r, foodweb, nothing) == 
            prodgrowth_α(i, B, r, foodweb, nothing) == 
            expected_growth[i]
    end

    # Extern method with intra and intercompetition
    p = ModelParameters(
        foodweb;
        producer_growth = LogisticGrowth(foodweb; αii = 1.0, αij = 1.0),
    )
    K, r, α = p.environment.K, p.biorates.r, p.producer_growth.α
    B = [0.5, 0.5, 0.5]
    for i in 1:3
        # It is like each producer had a density of one (look the "B * 2" in the
        # left call of the function)
        prodgrowth = LogisticGrowth(foodweb)
        prodgrowth_α = LogisticGrowth(foodweb, α = α)
        @test prodgrowth(i, B*2, r, foodweb, nothing) == 
            prodgrowth_α(i, B, r, foodweb, nothing) == 
            0.0
    end

    # Test producer competition
    # 1 & 2 producer; 3 consumer
    A = [0 0 0; 0 0 0; 0 0 1]
    foodweb = FoodWeb(A; quiet = true)
    rates = BioRates(foodweb; d = 0)
    # K = 1, intercompetition (default)
    p = ModelParameters(
        foodweb;
        producer_growth = LogisticGrowth(foodweb; αii = 1.0, αij = 1.0),
        biorates = rates
    )
    @test simulates(p, [0.5, 0.5, 0.5])[1:2, end] == [0.5, 0.5]

    p_inter_only = ModelParameters(
        foodweb;
        producer_growth = LogisticGrowth(foodweb; αii = 0.0, αij = 1.0),
        biorates = rates,
    )
    s_inter_only = simulates(p_inter_only, [0.5, 0.5, 0.5])
    p_intra_only = ModelParameters(
        foodweb;
        producer_growth = LogisticGrowth(foodweb; αii = 1.0, αij = 0.0),
        biorates = rates,
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
    K, r = p.producer_growth.Kᵢ, p.biorates.r
    B = [1, 1, 1]
    @test p.producer_growth(1, B, r, multiplex_network) == 0
    @test p.producer_growth(2, B, r, multiplex_network) == 0
    @test p.producer_growth(3, B, r, multiplex_network) == 0
    B = [0.5, 0.5, 0.5]
    @test p.producer_growth(1, B, r, multiplex_network) == 0.25
    @test p.producer_growth(2, B, r, multiplex_network) == 0.25
    @test p.producer_growth(3, B, r, multiplex_network) == 0
    rates = BioRates(multiplex_network; r = 2)
    p = ModelParameters(multiplex_network; functional_response = response, biorates = rates)
    K, r = p.producer_growth.Kᵢ, p.biorates.r
    @test p.producer_growth(1, B, r, multiplex_network) == 0.5
    @test p.producer_growth(2, B, r, multiplex_network) == 0.5
    @test p.producer_growth(3, B, r, multiplex_network) == 0
    # Facilitation > 0 <=> the growth is changed (compared to above section)
    for f0 in [1.0, 2.0, 5.0, 10.0]
        multiplex_network.layers[:facilitation].intensity = f0
        p = ModelParameters(multiplex_network; functional_response = response)
        K, r = p.producer_growth.Kᵢ, p.biorates.r
        B = [1, 1, 1]
        @test p.producer_growth(
            1,
            B,
            r,
            multiplex_network,
        ) == 0
        @test p.producer_growth(
            2,
            B,
            r,
            multiplex_network,
        ) == 0
        @test p.producer_growth(
            3,
            B,
            r,
            multiplex_network,
        ) == 0
        B = [0.5, 0.5, 0.5]
        @test p.producer_growth(
            1,
            B,
            r,
            multiplex_network
        ) == 0.25 * (1 + f0)
        @test p.producer_growth(
            2,
            B,
            r,
            multiplex_network
        ) == 0.25 * (1 + f0)
        @test p.producer_growth(
            3,
            B,
            r,
            multiplex_network
        ) == 0
        rates = BioRates(multiplex_network; r = 2)
        p = ModelParameters(
            multiplex_network;
            functional_response = response,
            biorates = rates
        )
        K, r = p.producer_growth.Kᵢ, p.biorates.r
        @test p.producer_growth(
            1,
            B,
            r,
            multiplex_network,
        ) == 0.5 * (1 + f0)
        @test p.producer_growth(
            2,
            B,
            r,
            multiplex_network,
        ) == 0.5 * (1 + f0)
        @test p.producer_growth(
            3,
            B,
            r,
            multiplex_network,
        ) == 0
    end
end
