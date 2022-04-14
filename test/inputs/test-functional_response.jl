@testset "Assimilation efficiency" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])
    e_expect = sparse([0 0 0; 1 0 0; 1 2 0])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=1, e_carnivore=2) == e_expect
    e_expect = sparse([0 0 0; 3 0 0; 3 4 0])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=3, e_carnivore=4) == e_expect
    foodweb = FoodWeb([0 0 0; 1 1 0; 1 1 1])
    e_expect = sparse([0 0 0; 1 2 0; 1 2 2])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=1, e_carnivore=2) == e_expect
end

A1 = [0 0; 1 0] # 2 eats 1
A2 = [0 0 0; 1 0 0; 1 1 0] # 2 eats 1; 3 eats 1 & 2
foodweb1 = FoodWeb(A1)
foodweb2 = FoodWeb(A2)

@testset "Bioenergetic functional response parameters" begin
    # Default
    Fbioenergetic_1 = BioenergeticResponse(foodweb1)
    @test Fbioenergetic_1.B0 == [0.5, 0.5]
    @test Fbioenergetic_1.h == 2.0
    @test Fbioenergetic_1.c == [0.0, 0.0]

    # Custom
    Fbioenergetic_1 = BioenergeticResponse(foodweb1, B0=3.0, h=1.0, c=0.5)
    @test Fbioenergetic_1.B0 == [3.0, 3.0]
    @test Fbioenergetic_1.h == 1.0
    @test Fbioenergetic_1.c == [0.5, 0.5]

    # Preferency matrix
    Fbioenergetic_2 = BioenergeticResponse(foodweb2)
    @test Fbioenergetic_1.ω == sparse([0 0; 1 0])
    @test Fbioenergetic_2.ω == sparse([0 0 0; 1 0 0; 0.5 0.5 0])
end

@testset "Classic functional response parameters" begin
    # Default
    Fclassic_1 = ClassicResponse(foodweb1)
    @test Fclassic_1.h == 2.0
    @test Fclassic_1.aᵣ == sparse([0 0; 0.5 0])
    @test Fclassic_1.hₜ == sparse([0 0; 1 0])
    @test Fclassic_1.c == [0.0, 0.0]

    # Custom
    Fclassic_1 = ClassicResponse(foodweb1, h=1.0, aᵣ=[0 0; 0.2 0], hₜ=5, c=0.6)
    @test Fclassic_1.h == 1.0
    @test Fclassic_1.aᵣ == sparse([0 0; 0.2 0])
    @test Fclassic_1.hₜ == sparse([0 0; 5 0])
    @test Fclassic_1.c == [0.6, 0.6]

    # Preferency matrix
    Fclassic_2 = ClassicResponse(foodweb2)
    @test Fclassic_1.ω == sparse([0 0; 1 0])
    @test Fclassic_2.ω == sparse([0 0 0; 1 0 0; 0.5 0.5 0])
end
