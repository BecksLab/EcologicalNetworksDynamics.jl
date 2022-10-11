@testset "ProducerCompetition" begin
    foodweb = FoodWeb([0 0 0; 0 0 0; 0 1 0])
    compet = ProducerCompetition(foodweb) # default
    @test compet.α == [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 0.0]
    @test compet.αii == 1.0
    @test compet.αij == 0.0
    compet = ProducerCompetition(foodweb; αii = 1.0, αij = 1.0) # Put intercompetition
    # Competition terms are 0 for all αij involving non-producers 
    @test compet.α == [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]
    @test compet.αii == 1.0
    @test compet.αij == 1.0
end
