@testset "Consumption: bioenergetic" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])

    # Bioenergetic - default
    p = ModelParameters(foodweb)
    B = [1, 1, 1]
    fᵣmatrix = p.functional_response(B)
    eating1, being_eaten1 = BEFWM2.consumption(1, B, p, fᵣmatrix)
    eating2, being_eaten2 = BEFWM2.consumption(2, B, p, fᵣmatrix)
    eating3, being_eaten3 = BEFWM2.consumption(3, B, p, fᵣmatrix)
    @test eating1 ≈ 0 atol = 1e-5 # species 1 does not eat
    @test (eating2 > 0) & (eating3 > 0) # species 2 & 3 eat
    @test being_eaten3 ≈ 0 atol = 1e-5 # species 3 is not eaten
    @test being_eaten1 > being_eaten2 > 0 # species 1 & 2 are eaten
    B₂ = [2, 1, 1] # increasing producer biomass...
    fᵣmatrix₂ = p.functional_response(B₂)
    eating₂1, being_eaten₂1 = BEFWM2.consumption(1, B₂, p, fᵣmatrix₂)
    eating₂2, being_eaten₂2 = BEFWM2.consumption(2, B₂, p, fᵣmatrix₂)
    eating₂3, being_eaten₂3 = BEFWM2.consumption(3, B₂, p, fᵣmatrix₂)
    @test eating₂2 > eating₂3 #... benefits more to the species feeding only on producer
    @test being_eaten₂1 > being_eaten1 #... and more producer biomass is consumed

    # Bionergetic with intraspecific interference
    F = BioenergeticResponse(foodweb, c=[0, 0, 0.5]) # intra interference for species 3
    p = ModelParameters(foodweb, functional_response=F)
    fᵣmatrix = p.functional_response(B)
    eatingᵢ1, being_eatenᵢ1 = BEFWM2.consumption(1, B, p, fᵣmatrix)
    eatingᵢ2, being_eatenᵢ2 = BEFWM2.consumption(2, B, p, fᵣmatrix)
    eatingᵢ3, being_eatenᵢ3 = BEFWM2.consumption(3, B, p, fᵣmatrix)
    @test eatingᵢ1 ≈ 0 atol = 1e-5
    @test being_eatenᵢ3 ≈ 0 atol = 1e-5
    @test eatingᵢ2 ≈ eating2 atol = 1e-5 # no change for species 2
    @test eatingᵢ3 < eating3 # decrease of species 3 consumption
end

@testset "Consumption: classic" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])

    # Bioenergetic - default
    p = ModelParameters(foodweb, functional_response=ClassicResponse(foodweb))
    B = [1, 1, 1]
    fᵣmatrix = p.functional_response(B)
    eating1, being_eaten1 = BEFWM2.consumption(1, B, p, fᵣmatrix)
    eating2, being_eaten2 = BEFWM2.consumption(2, B, p, fᵣmatrix)
    eating3, being_eaten3 = BEFWM2.consumption(3, B, p, fᵣmatrix)
    @test eating1 ≈ 0 atol = 1e-5 # species 1 does not eat
    @test (eating2 > 0) & (eating3 > 0) # species 2 & 3 eat
    @test being_eaten3 ≈ 0 atol = 1e-5 # species 3 is not eaten
    @test being_eaten1 > being_eaten2 > 0 # species 1 & 2 are eaten
    B₂ = [2, 1, 1] # increasing producer biomass...
    fᵣmatrix₂ = p.functional_response(B₂)
    eating₂1, being_eaten₂1 = BEFWM2.consumption(1, B₂, p, fᵣmatrix₂)
    eating₂2, being_eaten₂2 = BEFWM2.consumption(2, B₂, p, fᵣmatrix₂)
    eating₂3, being_eaten₂3 = BEFWM2.consumption(3, B₂, p, fᵣmatrix₂)
    @test eating₂2 > eating₂3 #... benefits more to the species feeding only on producer
    @test being_eaten₂1 > being_eaten1 #... and more producer biomass is consumed

    # Bionergetic with intraspecific interference
    F = ClassicResponse(foodweb, c=[0, 0, 0.5]) # intra interference for species 3
    p = ModelParameters(foodweb, functional_response=F)
    fᵣmatrix = p.functional_response(B)
    eatingᵢ1, being_eatenᵢ1 = BEFWM2.consumption(1, B, p, fᵣmatrix)
    eatingᵢ2, being_eatenᵢ2 = BEFWM2.consumption(2, B, p, fᵣmatrix)
    eatingᵢ3, being_eatenᵢ3 = BEFWM2.consumption(3, B, p, fᵣmatrix)
    @test eatingᵢ1 ≈ 0 atol = 1e-5
    @test being_eatenᵢ3 ≈ 0 atol = 1e-5
    @test eatingᵢ2 ≈ eating2 atol = 1e-5 # no change for species 2
    @test eatingᵢ3 < eating3 # decrease of species 3 consumption
end
