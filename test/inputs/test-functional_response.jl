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

@testset "Bioenergetic functional response functor" begin
    # Index by index
    Fbioenergetic_1 = BioenergeticResponse(foodweb1)
    @test Fbioenergetic_1([1, 1], 1, 1) == 0 # no interaction
    @test Fbioenergetic_1([1, 1], 1, 2) == 0 # no interaction
    @test Fbioenergetic_1([1, 1], 2, 2) == 0 # no interaction
    @test Fbioenergetic_1([1, 1], 2, 1) == 1^2 / (0.5^2 + 1^2) # interaction
    @test Fbioenergetic_1([1, 2], 2, 1) == 1^2 / (0.5^2 + 1^2) # don't depend on cons. mass
    @test Fbioenergetic_1([2, 1], 2, 1) == 2^2 / (0.5^2 + 2^2) # ...but depend on res. mass

    # Matrix
    F21 = 1^2 / (0.5^2 + 1^2)
    @test Fbioenergetic_1([1, 1]) == sparse([0 0; F21 0]) # provide biomass vector
    @test Fbioenergetic_1(1) == sparse([0 0; F21 0]) # or a scalar if same for all species

    # Non-default hill exponent
    Fbioenergetic_1 = BioenergeticResponse(foodweb1, h=3)
    F21 = 2^3 / (0.5^3 + 2^3)
    @test Fbioenergetic_1(2) == sparse([0 0; F21 0])

    # Consumer feeding on several resources
    Fbioenergetic_2 = BioenergeticResponse(foodweb2)
    B = [1, 1, 1] # uniform biomass distribution
    F21 = 1^2 / (0.5^2 + 1^2)
    F31 = 0.5 * 1^2 / ((0.5^2) + (0.5 * 1^2) + (0.5 * 1^2))
    F32 = F31
    @test Fbioenergetic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = 3^2 / (0.5^2 + 3^2)
    F31 = 0.5 * 3^2 / ((0.5^2) + (0.5 * 3^2) + (0.5 * 2^2))
    F32 = 0.5 * 2^2 / ((0.5^2) + (0.5 * 3^2) + (0.5 * 2^2))
    @test Fbioenergetic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])

    # Adding intraspecific interference
    Fbioenergetic_2 = BioenergeticResponse(foodweb2, c=1)
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = 3^2 / (0.5^2 + 1 * 2 * 0.5^2 + 3^2)
    F31 = 0.5 * 3^2 / ((0.5^2) + (1 * 1 * 0.5^2) + (0.5 * 3^2 + 0.5 * 2^2))
    F32 = 0.5 * 2^2 / ((0.5^2) + (1 * 1 * 0.5^2) + (0.5 * 3^2 + 0.5 * 2^2))
    @test Fbioenergetic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
end

@testset "Classic functional response functor" begin
    # Index by index
    Fclassic_1 = ClassicResponse(foodweb1)
    @test Fclassic_1([1, 1], 1, 1) == 0 # no interaction
    @test Fclassic_1([1, 1], 1, 2) == 0 # no interaction
    @test Fclassic_1([1, 1], 2, 2) == 0 # no interaction
    F21 = (1 * 0.5 * 1^2) / (1 + 0.5 * 1 * 1^2)
    @test Fclassic_1([1, 1], 2, 1) == F21 # interaction
    @test Fclassic_1([1, 2], 2, 1) == F21 # don't depend on cons. mass
    F21_new = (1 * 0.5 * 2^2) / (1 + 0.5 * 1 * 2^2)
    @test Fclassic_1([2, 1], 2, 1) == F21_new # ...but depend on res. mass

    # Matrix
    @test Fclassic_1([1, 1]) == sparse([0 0; F21 0]) # provide biomass vector
    @test Fclassic_1(1) == sparse([0 0; F21 0]) # or a scalar if same for all species

    # Non-default hill exponent
    Fclassic_1 = ClassicResponse(foodweb1, h=3)
    F21 = (1 * 0.5 * 2^3) / (1 + 0.5 * 1 * 2^3)
    @test Fclassic_1(2) == sparse([0 0; F21 0])

    # Non-default attack rate
    Fclassic_1 = ClassicResponse(foodweb1, aᵣ=0.2)
    F21 = (1 * 0.2 * 2^2) / (1 + 0.2 * 1 * 2^2)
    @test Fclassic_1(2) == sparse([0 0; F21 0])

    # Non-default handling time
    Fclassic_1 = ClassicResponse(foodweb1, hₜ=2)
    F21 = (1 * 0.5 * 2^2) / (1 + 0.5 * 2 * 2^2)
    @test Fclassic_1(2) == sparse([0 0; F21 0])


    # Consumer feeding on several resources
    Fclassic_2 = ClassicResponse(foodweb2)
    B = [1, 1, 1] # uniform biomass distribution
    F21 = (1 * 0.5 * 1^2) / (1 + 0.5 * 1 * 1^2)
    F31 = (0.5 * 0.5 * 1^2) / (1 + 0.5 * 0.5 * 1 * 1^2 + 0.5 * 0.5 * 1 * 1^2)
    F32 = F31
    @test Fclassic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    @test Fclassic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B, aᵣ = [3, 2, 1], [0 0 0; 0.5 0 0; 0.5 0.2 0] # non-uniform biomass...
    Fclassic_2 = ClassicResponse(foodweb2, aᵣ=aᵣ) #...and non-uniform attack rate
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.2 * 1 * 2^2)
    F32 = (0.5 * 0.2 * 2^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.2 * 1 * 2^2)
    @test Fclassic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B, hₜ = [3, 2, 1], [0 0 0; 0.9 0 0; 0.7 0.2 0] # non-uniform biomass...
    Fclassic_2 = ClassicResponse(foodweb2, hₜ=hₜ) #...and non-uniform handling time
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 0.9 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 0.7 * 3^2 + 0.5 * 0.5 * 0.2 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 0.5 * 0.5 * 0.7 * 3^2 + 0.5 * 0.5 * 0.2 * 2^2)
    @test Fclassic_2(B) ≈ sparse([0 0 0; F21 0 0; F31 F32 0]) atol = 1e-5

    # Adding intraspecific interference
    Fclassic_2 = ClassicResponse(foodweb2, c=1)
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = (1 * 0.5 * 3^2) / (1 + 1 * 2 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 1 * 1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 1 * 1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    @test Fclassic_2(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
end
