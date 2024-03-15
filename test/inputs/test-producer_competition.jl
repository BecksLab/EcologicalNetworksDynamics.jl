@testset "ProducerCompetition" begin
    foodweb = FoodWeb([0 0 0; 0 0 0; 0 1 0])
    compet = ProducerCompetition(foodweb) # default
    @test compet.α == [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 0.0]
    compet = ProducerCompetition(foodweb; αii = 1.0, αij = 1.0) # Put intercompetition
    # Competition terms are 0 for all αij involving non-producers 
    @test compet.α == [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]
    # Test that custom matrices work
    myα = [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]
    compet = ProducerCompetition(foodweb; α = myα)
    @test compet.α == [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]
    # Should fail if non zero α for non-producers
    @test_throws AssertionError("all(α[non_producer, :] .== 0)") ProducerCompetition(
        foodweb,
        α = [1.0 1.0 0.0; 1.0 1.0 0.0; 1.0 0.0 0.0],
    )
    # Should fail if the α matrix dim does not match the size of the foodweb 
    @test_throws AssertionError("size(α, 1) == size(α, 2) == S") ProducerCompetition(
        foodweb,
        α = [1.0 0.0; 1.0 0.0; 0.0 0.0],
    )
    @test_throws AssertionError("size(α, 1) == size(α, 2) == S") ProducerCompetition(
        foodweb,
        α = [1.0 0.0; 1.0 0.0],
    )
end
