@testset "Consumption: bioenergetic" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])

    # Bioenergetic - default
    p = ModelParameters(foodweb)
    B = [1, 1, 1]
    biorates, environment, F = p.BioRates, p.Environment, p.FunctionalResponse
    eating, being_eaten = BEFWM2.consumption(B, foodweb, biorates, F, environment)
    @test eating[1] ≈ 0 atol = 1e-5 # species 1 does not eat
    @test (eating[2] > 0) & (eating[3] > 0) # species 2 & 3 eat
    @test being_eaten[3] ≈ 0 atol = 1e-5 # species 3 is not eaten
    @test being_eaten[1] > being_eaten[2] > 0 # species 1 & 2 are eaten
    B₂ = [2, 1, 1] # increasing producer biomass...
    eating₂, being_eaten₂ = BEFWM2.consumption(B₂, foodweb, biorates, F, environment)
    @test eating₂[2] > eating₂[3] #... benefits more to the species feeding only on producer
    @test being_eaten₂[1] > being_eaten[1] #... and more producer biomass is consumed

    # Bionergetic with intraspecific interference
    F = BioenergeticResponse(foodweb, c=[0, 0, 0.5]) # intra interference for species 3
    p = ModelParameters(foodweb, FunctionalResponse=F)
    biorates, environment, F = p.BioRates, p.Environment, p.FunctionalResponse
    eatingᵢ, being_eatenᵢ = BEFWM2.consumption(B, foodweb, biorates, F, environment)
    @test eatingᵢ[1] ≈ 0 atol = 1e-5
    @test being_eatenᵢ[3] ≈ 0 atol = 1e-5
    @test eatingᵢ[2] ≈ eating[2] atol = 1e-5 # no change for species 2
    @test eatingᵢ[3] < eating[3] # decrease of species 3 consumption
end

@testset "Consumption: classic" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])

    # Classic - default
    p = ModelParameters(foodweb, FunctionalResponse=ClassicResponse(foodweb))
    B = [1, 1, 1]
    biorates, environment, F = p.BioRates, p.Environment, p.FunctionalResponse
    eating, being_eaten = BEFWM2.consumption(B, foodweb, biorates, F, environment)
    @test eating[1] ≈ 0 atol = 1e-5 # species 1 does not eat
    @test (eating[2] > 0) & (eating[3] > 0) # species 2 & 3 eat
    @test being_eaten[3] ≈ 0 atol = 1e-5 # species 3 is not eaten
    @test being_eaten[1] > being_eaten[2] > 0 # species 1 & 2 are eaten
    B₂ = [2, 1, 1] # increasing producer biomass...
    eating₂, being_eaten₂ = BEFWM2.consumption(B₂, foodweb, biorates, F, environment)
    @test eating₂[2] > eating₂[3] #... benefits more to the species feeding only on producer
    @test being_eaten₂[1] > being_eaten[1] #... and more producer biomass is consumed

    # Classic with intraspecific interference
    F = ClassicResponse(foodweb, c=[0, 0, 0.5]) # intra interference for species 3
    p = ModelParameters(foodweb, FunctionalResponse=F)
    biorates, environment, F = p.BioRates, p.Environment, p.FunctionalResponse
    eatingᵢ, being_eatenᵢ = BEFWM2.consumption(B, foodweb, biorates, F, environment)
    @test eatingᵢ[1] ≈ 0 atol = 1e-5
    @test being_eatenᵢ[3] ≈ 0 atol = 1e-5
    @test eatingᵢ[2] ≈ eating[2] atol = 1e-5 # no change for species 2
    @test eatingᵢ[3] < eating[3] # decrease of species 3 consumption
end
