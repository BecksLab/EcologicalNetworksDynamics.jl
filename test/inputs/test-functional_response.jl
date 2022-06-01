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
multi_net1 = MultiplexNetwork(foodweb1)
foodweb2 = FoodWeb(A2)
intensity = NonTrophicIntensity(0.0, 0.0, 0.0, 0.0)
multi_net2 = MultiplexNetwork(foodweb2, intensity=intensity, C_interference=1.0)

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

@testset "Linear functional response parameters" begin
    # Default
    Flinear_1 = LinearResponse(foodweb1)
    @test Flinear_1.α == sparse([0, 1.0])
    @test Flinear_1.ω == sparse([0 0; 1.0 0.0])

    # Custom
    Flinear_1 = LinearResponse(foodweb1, α=[0.0, 2.0])
    @test Flinear_1.α == sparse([0, 2.0])
    @test Flinear_1.ω == sparse([0 0; 1.0 0.0])

    # Custom and foodweb2
    Flinear_2 = LinearResponse(foodweb2, α=3.0)
    @test Flinear_2.α == sparse([0, 3.0, 3.0])
    @test Flinear_2.ω == sparse([0 0 0; 1 0 0; 0.5 0.5 0])
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
    # Index by index - FoodWeb
    Fbioenergetic1_fw = BioenergeticResponse(foodweb1)
    @test Fbioenergetic1_fw([1, 1], 1, 1) == 0 # no interaction
    @test Fbioenergetic1_fw([1, 1], 1, 2) == 0 # no interaction
    @test Fbioenergetic1_fw([1, 1], 2, 2) == 0 # no interaction
    @test Fbioenergetic1_fw([1, 1], 2, 1) == 1^2 / (0.5^2 + 1^2) # interaction
    @test Fbioenergetic1_fw([1, 2], 2, 1) == 1^2 / (0.5^2 + 1^2) # don't depend on cons. mass
    @test Fbioenergetic1_fw([2, 1], 2, 1) == 2^2 / (0.5^2 + 2^2) # ...but depend on res. mass

    # Index by index - FoodWeb
    Fbioenergetic1_nti = BioenergeticResponse(multi_net1)
    @test Fbioenergetic1_nti([1, 1], 1, 1) == 0 # no interaction
    @test Fbioenergetic1_nti([1, 1], 1, 2) == 0 # no interaction
    @test Fbioenergetic1_nti([1, 1], 2, 2) == 0 # no interaction
    @test Fbioenergetic1_nti([1, 1], 2, 1) == 1^2 / (0.5^2 + 1^2) # interaction
    @test Fbioenergetic1_nti([1, 2], 2, 1) == 1^2 / (0.5^2 + 1^2) # don't depend on cons. mass
    @test Fbioenergetic1_nti([2, 1], 2, 1) == 2^2 / (0.5^2 + 2^2) # ...but depend on res. mass

    # Matrix
    F21 = 1^2 / (0.5^2 + 1^2)
    @test Fbioenergetic1_fw([1, 1]) == sparse([0 0; F21 0]) # provide biomass vector
    @test Fbioenergetic1_fw([1, 1], foodweb1) == sparse([0 0; F21 0]) # method consistency
    @test Fbioenergetic1_fw([1, 1], multi_net1) == sparse([0 0; F21 0]) # method consistency
    @test Fbioenergetic1_fw(1) == sparse([0 0; F21 0]) # or a scalar if same for all species

    # Non-default hill exponent
    Fbioenergetic_1 = BioenergeticResponse(foodweb1, h=3)
    F21 = 2^3 / (0.5^3 + 2^3)
    @test Fbioenergetic_1(2) == sparse([0 0; F21 0])
    @test Fbioenergetic_1(2, foodweb1) == sparse([0 0; F21 0]) # method consistency
    @test Fbioenergetic_1(2, multi_net1) == sparse([0 0; F21 0]) # nti=0 ⟺ foodweb

    # Consumer feeding on several resources
    Fbioenergetic2_fw = BioenergeticResponse(foodweb2)
    Fbioenergetic2_nti = BioenergeticResponse(multi_net2)
    B = [1, 1, 1] # uniform biomass distribution
    F21 = 1^2 / (0.5^2 + 1^2)
    F31 = 0.5 * 1^2 / ((0.5^2) + (0.5 * 1^2) + (0.5 * 1^2))
    F32 = F31
    @test Fbioenergetic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_fw(B, foodweb2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = 3^2 / (0.5^2 + 3^2)
    F31 = 0.5 * 3^2 / ((0.5^2) + (0.5 * 3^2) + (0.5 * 2^2))
    F32 = 0.5 * 2^2 / ((0.5^2) + (0.5 * 3^2) + (0.5 * 2^2))
    @test Fbioenergetic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_fw(B, foodweb2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])

    # Adding intraspecific interference
    Fbioenergetic2_fw = BioenergeticResponse(foodweb2, c=1)
    Fbioenergetic2_nti = BioenergeticResponse(multi_net2, c=1)
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = 3^2 / (0.5^2 + 1 * 2 * 0.5^2 + 3^2)
    F31 = 0.5 * 3^2 / ((0.5^2) + (1 * 1 * 0.5^2) + (0.5 * 3^2 + 0.5 * 2^2))
    F32 = 0.5 * 2^2 / ((0.5^2) + (1 * 1 * 0.5^2) + (0.5 * 3^2 + 0.5 * 2^2))
    @test Fbioenergetic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_fw(B, foodweb2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fbioenergetic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
end

@testset "Linear functional response functor" begin
    # Index by index - FoodWeb
    Flinear1_fw = LinearResponse(foodweb1)
    @test Flinear1_fw([1, 1], 1, 1) == 0 # no interaction
    @test Flinear1_fw([1, 1], 1, 2) == 0 # no interaction
    @test Flinear1_fw([1, 1], 2, 2) == 0 # no interaction
    @test Flinear1_fw([1, 1], 2, 1) == 1.0 # interaction
    @test Flinear1_fw([1, 2], 2, 1) == 1.0 # don't depend on cons. mass
    @test Flinear1_fw([2, 1], 2, 1) == 2.0 # ...but depend on res. mass

    # Index by index - MultiplexNetwork
    Flinear1_nti = LinearResponse(multi_net1)
    @test Flinear1_nti([1, 1], 1, 1) == 0 # no interaction
    @test Flinear1_nti([1, 1], 1, 2) == 0 # no interaction
    @test Flinear1_nti([1, 1], 2, 2) == 0 # no interaction
    @test Flinear1_nti([1, 1], 2, 1) == 1.0 # interaction
    @test Flinear1_nti([1, 2], 2, 1) == 1.0 # don't depend on cons. mass
    @test Flinear1_nti([2, 1], 2, 1) == 2.0 # ...but depend on res. mass

    # Matrix
    @test Flinear1_fw([1, 1]) == sparse([0 0; 1.0 0]) # provide biomass vector
    @test Flinear1_fw(1) == sparse([0 0; 1.0 0]) # or a scalar if same for all species
    @test Flinear1_nti([1, 1]) == sparse([0 0; 1.0 0]) # provide biomass vector
    @test Flinear1_nti(1) == sparse([0 0; 1.0 0]) # or a scalar if same for all species
    @test Flinear1_nti([1, 1], foodweb1) == sparse([0 0; 1.0 0]) # provide biomass vector
    @test Flinear1_nti([1, 1], multi_net1) == sparse([0 0; 1.0 0]) # or a scalar if same for all species

    # Non-default consumption rate
    Flinear1_fw = LinearResponse(foodweb1, α=[0, 2.0])
    Flinear1_nti = LinearResponse(multi_net1, α=[0, 2.0])
    @test Flinear1_fw(2) == sparse([0 0; 4.0 0])
    @test Flinear1_nti(2) == sparse([0 0; 4.0 0])

    # Consumer feeding on several resources
    Flinear2_fw = LinearResponse(foodweb2, α=[0, 1, 2])
    Flinear2_nti = LinearResponse(multi_net2, α=[0, 1, 2])
    B = [3, 2, 1] # non-uniform biomass distribution
    @test Flinear2_fw(B) == sparse([0 0 0; 3 0 0; 3 2 0])
    @test Flinear2_nti(B) == sparse([0 0 0; 3 0 0; 3 2 0])
end

@testset "Classic functional response functor" begin
    # Index by index - FoodWeb
    Fclassic1_fw = ClassicResponse(foodweb1)
    @test Fclassic1_fw([1, 1], 1, 1) == 0 # no interaction
    @test Fclassic1_fw([1, 1], 1, 2) == 0 # no interaction
    @test Fclassic1_fw([1, 1], 2, 2) == 0 # no interaction
    F21 = (1 * 0.5 * 1^2) / (1 + 0.5 * 1 * 1^2)
    @test Fclassic1_fw([1, 1], 2, 1) == F21 # interaction
    @test Fclassic1_fw([1, 2], 2, 1) == F21 # don't depend on cons. mass
    F21_new = (1 * 0.5 * 2^2) / (1 + 0.5 * 1 * 2^2)
    @test Fclassic1_fw([2, 1], 2, 1) == F21_new # ...but depend on res. mass

    # Index by index - MultiplexNetwork
    Fclassic1_nti = ClassicResponse(multi_net1)
    @test Fclassic1_nti([1, 1], 1, 1) == 0 # no interaction
    @test Fclassic1_nti([1, 1], 1, 2) == 0 # no interaction
    @test Fclassic1_nti([1, 1], 2, 2) == 0 # no interaction
    F21 = (1 * 0.5 * 1^2) / (1 + 0.5 * 1 * 1^2)
    @test Fclassic1_nti([1, 1], 2, 1) == F21 # interaction
    @test Fclassic1_nti([1, 2], 2, 1) == F21 # don't depend on cons. mass
    F21_new = (1 * 0.5 * 2^2) / (1 + 0.5 * 1 * 2^2)
    @test Fclassic1_nti([2, 1], 2, 1) == F21_new # ...but depend on res. mass

    # Matrix
    @test Fclassic1_fw([1, 1], foodweb1) == sparse([0 0; F21 0]) # provide biomass vector
    @test Fclassic1_fw(1, foodweb1) == sparse([0 0; F21 0]) # or a scalar if same for all species
    @test Fclassic1_nti([1, 1], multi_net1) == sparse([0 0; F21 0]) # provide biomass vector
    @test Fclassic1_nti(1, multi_net1) == sparse([0 0; F21 0]) # or a scalar if same for all species

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
    Fclassic2_fw = ClassicResponse(foodweb2)
    Fclassic2_nti = ClassicResponse(multi_net2)
    B = [1, 1, 1] # uniform biomass distribution
    F21 = (1 * 0.5 * 1^2) / (1 + 0.5 * 1 * 1^2)
    F31 = (0.5 * 0.5 * 1^2) / (1 + 0.5 * 0.5 * 1 * 1^2 + 0.5 * 0.5 * 1 * 1^2)
    F32 = F31
    @test Fclassic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fclassic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    @test Fclassic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fclassic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B, aᵣ = [3, 2, 1], [0 0 0; 0.5 0 0; 0.5 0.2 0] # non-uniform biomass...
    Fclassic2_fw = ClassicResponse(foodweb2, aᵣ=aᵣ) #...and non-uniform attack rate
    Fclassic2_nti = ClassicResponse(multi_net2, aᵣ=aᵣ)
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.2 * 1 * 2^2)
    F32 = (0.5 * 0.2 * 2^2) / (1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.2 * 1 * 2^2)
    @test Fclassic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fclassic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    B, hₜ = [3, 2, 1], [0 0 0; 0.9 0 0; 0.7 0.2 0] # non-uniform biomass...
    Fclassic2_fw = ClassicResponse(foodweb2, hₜ=hₜ) #...and non-uniform handling time
    Fclassic2_nti = ClassicResponse(multi_net2, hₜ=hₜ)
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 0.9 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 0.5 * 0.7 * 3^2 + 0.5 * 0.5 * 0.2 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 0.5 * 0.5 * 0.7 * 3^2 + 0.5 * 0.5 * 0.2 * 2^2)
    @test Fclassic2_fw(B) ≈ sparse([0 0 0; F21 0 0; F31 F32 0]) atol = 1e-5
    @test Fclassic2_nti(B, multi_net2) ≈ sparse([0 0 0; F21 0 0; F31 F32 0]) atol = 1e-5

    # Adding intraspecific interference
    Fclassic2_fw = ClassicResponse(foodweb2, c=1)
    Fclassic2_nti = ClassicResponse(multi_net2, c=1)
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = (1 * 0.5 * 3^2) / (1 + 1 * 2 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 1 * 1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 1 * 1 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    @test Fclassic2_fw(B) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fclassic2_fw(B, foodweb2) == sparse([0 0 0; F21 0 0; F31 F32 0])
    @test Fclassic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])

    # Adding interspecific interference
    multi_net2.nontrophic_intensity.i0 = 0.6 # activate interspecific interference
    Fclassic2_nti = ClassicResponse(multi_net2, c=0.5) #! c=intraspecific interference
    B = [3, 2, 1] # non-uniform biomass distribution
    F21 = (1 * 0.5 * 3^2) / (1 + 0.5 * 2 + 0.6 * 1 + 0.5 * 1 * 3^2)
    F31 = (0.5 * 0.5 * 3^2) / (1 + 0.5 * 1 + 0.6 * 2 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    F32 = (0.5 * 0.5 * 2^2) / (1 + 0.5 * 1 + 0.6 * 2 + 0.5 * 0.5 * 1 * 3^2 + 0.5 * 0.5 * 1 * 2^2)
    @test Fclassic2_nti(B, multi_net2) == sparse([0 0 0; F21 0 0; F31 F32 0])
end
