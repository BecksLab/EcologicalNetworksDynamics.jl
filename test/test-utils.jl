#### Set up food webs for tests ####
foodweb_2links = FoodWeb([0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0])
foodweb_3links = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 0 0 1 0])
foodweb_5links = FoodWeb([0 0 0 0; 1 0 0 0; 1 1 1 0; 0 0 1 0])
foodweb_2links.metabolic_class =
    ["producer", "producer", "invertebrate", "ectotherm vertebrate"]
#### end ####

@testset "Identify metabolic classes, producers, preys and predators" begin
    # Function called on one species of the network (return a boolean)
    @test BEFWM2.isinvertebrate(1, foodweb_2links) == false
    @test BEFWM2.isinvertebrate(2, foodweb_2links) == false
    @test BEFWM2.isinvertebrate(3, foodweb_2links) == true
    @test BEFWM2.isinvertebrate(4, foodweb_2links) == false

    @test BEFWM2.isvertebrate(1, foodweb_2links) == false
    @test BEFWM2.isvertebrate(2, foodweb_2links) == false
    @test BEFWM2.isvertebrate(3, foodweb_2links) == false
    @test BEFWM2.isvertebrate(4, foodweb_2links) == true

    @test BEFWM2.isproducer(1, foodweb_2links) == true
    @test BEFWM2.isproducer(2, foodweb_2links) == true
    @test BEFWM2.isproducer(3, foodweb_2links) == false
    @test BEFWM2.isproducer(4, foodweb_2links) == false

    @test BEFWM2.ispredator(1, foodweb_2links) == false
    @test BEFWM2.ispredator(2, foodweb_2links) == false
    @test BEFWM2.ispredator(3, foodweb_2links) == true
    @test BEFWM2.ispredator(4, foodweb_2links) == true

    @test BEFWM2.isprey(1, foodweb_2links) == true
    @test BEFWM2.isprey(2, foodweb_2links) == true
    @test BEFWM2.isprey(3, foodweb_2links) == false
    @test BEFWM2.isprey(4, foodweb_2links) == false

    # Functions called on the whole network (return a vector of indexes)
    @test BEFWM2.invertebrates(foodweb_2links) == [3]
    @test BEFWM2.invertebrates(foodweb_2links) == [3]
    @test BEFWM2.invertebrates(foodweb_2links) == [3]

    @test BEFWM2.vertebrates(foodweb_2links) == [4]
    @test BEFWM2.vertebrates(foodweb_2links) == [4]
    @test BEFWM2.vertebrates(foodweb_2links) == [4]

    @test BEFWM2.producers(foodweb_2links) == [1, 2]
    @test BEFWM2.producers(foodweb_3links) == [1, 2]
    @test BEFWM2.producers(foodweb_5links) == [1]

    @test BEFWM2.predators(foodweb_2links) == [3, 4]
    @test BEFWM2.predators(foodweb_3links) == [3, 4]
    @test BEFWM2.predators(foodweb_5links) == [2, 3, 4]

    @test BEFWM2.preys(foodweb_2links) == [1, 2]
    @test BEFWM2.preys(foodweb_3links) == [1, 2, 3]
    @test BEFWM2.preys(foodweb_5links) == [1, 2, 3]
end

@testset "Find predators and preys of a given species" begin
    @test BEFWM2.preys_of(1, foodweb_5links) == []
    @test BEFWM2.preys_of(2, foodweb_5links) == [1]
    @test BEFWM2.preys_of(3, foodweb_5links) == [1, 2, 3]
    @test BEFWM2.preys_of(4, foodweb_5links) == [3]

    @test BEFWM2.predators_of(1, foodweb_5links) == [2, 3]
    @test BEFWM2.predators_of(2, foodweb_5links) == [3]
    @test BEFWM2.predators_of(3, foodweb_5links) == [3, 4]
    @test BEFWM2.predators_of(4, foodweb_5links) == []
end

@testset "Find predators sharing at least one prey" begin
    @test BEFWM2.share_prey(1, 2, foodweb_5links) == false
    @test BEFWM2.share_prey(2, 1, foodweb_5links) == false
    @test BEFWM2.share_prey(3, 2, foodweb_5links) == true
    @test BEFWM2.share_prey(2, 3, foodweb_5links) == true
    @test BEFWM2.share_prey(2, 4, foodweb_5links) == false
    @test BEFWM2.share_prey(4, 2, foodweb_5links) == false
    @test BEFWM2.share_prey(3, 4, foodweb_5links) == true
    @test BEFWM2.share_prey(4, 3, foodweb_5links) == true
end

@testset "Find number of resources of each species." begin
    @test BEFWM2.number_of_resource(foodweb_2links) == [0, 0, 1, 1]
    @test BEFWM2.number_of_resource(foodweb_3links) == [0, 0, 2, 1]
    @test BEFWM2.number_of_resource(foodweb_5links) == [0, 1, 3, 1]
end
