@testset "Effect of facilitation on intrinsic growth rate" begin
    foodweb = FoodWeb([0 0; 1 0])
    multi_net = MultiplexNetwork(foodweb, n_facilitation=1.0)

    # Default intensity: f0 = 1.0
    @test BEFWM2.effect_facilitation(1, 1, [1, 0], multi_net) == 1
    @test BEFWM2.effect_facilitation(10, 1, [1, 0], multi_net) == 10
    @test BEFWM2.effect_facilitation(10, 1, [1, 1], multi_net) == 20
    @test BEFWM2.effect_facilitation(10, 1, [1, 2], multi_net) == 30

    # Non default intensity: f0 = 5.0
    multi_net.facilitation_layer.intensity = 5.0
    @test BEFWM2.effect_facilitation(1, 1, [1, 0], multi_net) == 1
    @test BEFWM2.effect_facilitation(10, 1, [1, 0], multi_net) == 10
    @test BEFWM2.effect_facilitation(10, 1, [1, 1], multi_net) == 60
    @test BEFWM2.effect_facilitation(10, 1, [1, 2], multi_net) == 110

    # Custom functional form
    multi_net.facilitation_layer.f = (x, δx) -> x * (1 + 2 * δx) # fac. effect 2x stronger
    @test BEFWM2.effect_facilitation(1, 1, [1, 0], multi_net) == 1
    @test BEFWM2.effect_facilitation(10, 1, [1, 0], multi_net) == 10
    @test BEFWM2.effect_facilitation(10, 1, [1, 1], multi_net) == 110
    @test BEFWM2.effect_facilitation(10, 1, [1, 2], multi_net) == 210
end

@testset "Effect of refuge on attack rate" begin

    # 1 refuge link
    B = [1, 1, 1]
    for aᵣ in [0.1, 0.2, 0.3, 0.4, 0.5], r0 in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
        net_refuge.refuge_layer.intensity = r0
        aᵣ_matrix = sparse([0 0 0; aᵣ 0 0; aᵣ aᵣ 0])
        aᵣ_refuge_matrix = sparse([0 0 0; aᵣ 0 0; aᵣ aᵣ/(1+r0) 0])
        @test BEFWM2.effect_refuge(aᵣ_matrix, B, net_refuge) == aᵣ_refuge_matrix
    end

    # 2 refuge links
    A_refuge = sparse(Bool[0 1 1 0; 1 0 1 0; 0 0 0 0; 0 0 0 0])
    foodweb = FoodWeb(nichemodel, 4, C=0.3)
    net = MultiplexNetwork(foodweb, A_refuge=A_refuge)
    B = [1, 2, 3, 4]
    for aᵣ in [0.1, 0.2, 0.3, 0.4, 0.5], r0 in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
        net.refuge_layer.intensity = r0
        aᵣ_matrix = sparse([0 0 0 0; 0 0 0 0; aᵣ 0 0 0; aᵣ aᵣ aᵣ 0])
        aᵣ31 = aᵣ / (1 + 2 * r0)
        aᵣ41 = aᵣ / (1 + 2 * r0)
        aᵣ42 = aᵣ / (1 + 1 * r0)
        aᵣ43 = aᵣ / (1 + 1 * r0 + 2 * r0)
        aᵣ_refuge_matrix = sparse([0 0 0 0; 0 0 0 0; aᵣ31 0 0 0; aᵣ41 aᵣ42 aᵣ43 0])
        @test BEFWM2.effect_refuge(aᵣ_matrix, B, net) == aᵣ_refuge_matrix
    end
end
