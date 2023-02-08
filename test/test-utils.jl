#### Set up food webs for tests ####
foodweb_2links = FoodWeb([0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0]; quiet = true)
foodweb_3links = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 0 0 1 0])
foodweb_5links = FoodWeb([0 0 0 0; 1 0 0 0; 1 1 1 0; 0 0 1 0]; quiet = true)
foodweb_2links.metabolic_class =
    ["producer", "producer", "invertebrate", "ectotherm vertebrate"]
#### end ####

@testset "Identify metabolic classes, producers, preys and predators" begin
    # Function called on one species of the network (return a boolean)
    @test EcologicalNetworksDynamics.isinvertebrate(1, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isinvertebrate(2, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isinvertebrate(3, foodweb_2links) == true
    @test EcologicalNetworksDynamics.isinvertebrate(4, foodweb_2links) == false

    @test EcologicalNetworksDynamics.isvertebrate(1, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isvertebrate(2, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isvertebrate(3, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isvertebrate(4, foodweb_2links) == true

    @test EcologicalNetworksDynamics.isproducer(1, foodweb_2links) == true
    @test EcologicalNetworksDynamics.isproducer(2, foodweb_2links) == true
    @test EcologicalNetworksDynamics.isproducer(3, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isproducer(4, foodweb_2links) == false

    @test EcologicalNetworksDynamics.ispredator(1, foodweb_2links) == false
    @test EcologicalNetworksDynamics.ispredator(2, foodweb_2links) == false
    @test EcologicalNetworksDynamics.ispredator(3, foodweb_2links) == true
    @test EcologicalNetworksDynamics.ispredator(4, foodweb_2links) == true

    @test EcologicalNetworksDynamics.isprey(1, foodweb_2links) == true
    @test EcologicalNetworksDynamics.isprey(2, foodweb_2links) == true
    @test EcologicalNetworksDynamics.isprey(3, foodweb_2links) == false
    @test EcologicalNetworksDynamics.isprey(4, foodweb_2links) == false

    # Functions called on the whole network (return a vector of indexes)
    @test EcologicalNetworksDynamics.invertebrates(foodweb_2links) == [3]
    @test EcologicalNetworksDynamics.invertebrates(foodweb_2links) == [3]
    @test EcologicalNetworksDynamics.invertebrates(foodweb_2links) == [3]

    @test EcologicalNetworksDynamics.vertebrates(foodweb_2links) == [4]
    @test EcologicalNetworksDynamics.vertebrates(foodweb_2links) == [4]
    @test EcologicalNetworksDynamics.vertebrates(foodweb_2links) == [4]

    @test EcologicalNetworksDynamics.producers(foodweb_2links) == [1, 2]
    @test EcologicalNetworksDynamics.producers(foodweb_3links) == [1, 2]
    @test EcologicalNetworksDynamics.producers(foodweb_5links) == [1]
    @test EcologicalNetworksDynamics.producers(foodweb_2links.A) == [1, 2]
    @test EcologicalNetworksDynamics.producers(foodweb_3links.A) == [1, 2]
    @test EcologicalNetworksDynamics.producers(foodweb_5links.A) == [1]

    @test EcologicalNetworksDynamics.predators(foodweb_2links) == [3, 4]
    @test EcologicalNetworksDynamics.predators(foodweb_3links) == [3, 4]
    @test EcologicalNetworksDynamics.predators(foodweb_5links) == [2, 3, 4]

    @test EcologicalNetworksDynamics.preys(foodweb_2links) == [1, 2]
    @test EcologicalNetworksDynamics.preys(foodweb_3links) == [1, 2, 3]
    @test EcologicalNetworksDynamics.preys(foodweb_5links) == [1, 2, 3]

    @test trophic_levels(foodweb_2links) == [1.0, 1.0, 2.0, 2.0]
    @test trophic_levels(foodweb_3links) == [1.0, 1.0, 2.0, 3.0]
    @test trophic_levels([0 1 0; 0 0 0; 1 0 0]) == [2.0, 1.0, 3.0]
end

@testset "Find predators and preys of a given species" begin
    @test EcologicalNetworksDynamics.preys_of(1, foodweb_5links) == []
    @test EcologicalNetworksDynamics.preys_of(2, foodweb_5links) == [1]
    @test EcologicalNetworksDynamics.preys_of(3, foodweb_5links) == [1, 2, 3]
    @test EcologicalNetworksDynamics.preys_of(4, foodweb_5links) == [3]

    @test EcologicalNetworksDynamics.predators_of(1, foodweb_5links) == [2, 3]
    @test EcologicalNetworksDynamics.predators_of(2, foodweb_5links) == [3]
    @test EcologicalNetworksDynamics.predators_of(3, foodweb_5links) == [3, 4]
    @test EcologicalNetworksDynamics.predators_of(4, foodweb_5links) == []
end

@testset "Find predators sharing at least one prey" begin
    @test EcologicalNetworksDynamics.share_prey(1, 2, foodweb_5links) == false
    @test EcologicalNetworksDynamics.share_prey(2, 1, foodweb_5links) == false
    @test EcologicalNetworksDynamics.share_prey(3, 2, foodweb_5links) == true
    @test EcologicalNetworksDynamics.share_prey(2, 3, foodweb_5links) == true
    @test EcologicalNetworksDynamics.share_prey(2, 4, foodweb_5links) == false
    @test EcologicalNetworksDynamics.share_prey(4, 2, foodweb_5links) == false
    @test EcologicalNetworksDynamics.share_prey(3, 4, foodweb_5links) == true
    @test EcologicalNetworksDynamics.share_prey(4, 3, foodweb_5links) == true
end

@testset "Find number of resources of each species." begin
    @test EcologicalNetworksDynamics.number_of_resource(foodweb_2links) == [0, 0, 1, 1]
    @test EcologicalNetworksDynamics.number_of_resource(foodweb_3links) == [0, 0, 2, 1]
    @test EcologicalNetworksDynamics.number_of_resource(foodweb_5links) == [0, 1, 3, 1]
end
