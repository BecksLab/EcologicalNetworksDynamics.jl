foodweb_2links = FoodWeb([0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0])
foodweb_2links.metabolic_class = [
    "producer",
    "producer",
    "invertebrate",
    "ectotherm vertebrate"
]
foodweb_3links = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 0 0 1 0])
foodweb_5links = FoodWeb([0 0 0 0; 1 0 0 0; 1 1 1 0; 0 0 1 0])

@testset "Identify metabolic classes, preys and predators." begin
    @test BEFWM2.producers(foodweb_2links) == [1, 2]
    @test BEFWM2.invertebrates(foodweb_2links) == [3]
    @test BEFWM2.vertebrates(foodweb_2links) == [4]

    @test BEFWM2.isproducer(1, foodweb_2links) == true
    @test BEFWM2.isproducer(2, foodweb_2links) == true
    @test BEFWM2.isproducer(3, foodweb_2links) == false
    @test BEFWM2.isproducer(4, foodweb_2links) == false

    @test BEFWM2.preys(foodweb_3links) == [1, 2, 3]
    @test BEFWM2.predators(foodweb_3links) == [3, 4]
    @test BEFWM2.preys(foodweb_2links) == [1, 2]
    @test BEFWM2.predators(foodweb_2links) == [3, 4]
end

@testset "Find predators who share at least one prey." begin
    expected = [
        (1, 2, false),
        (2, 1, false),
        (3, 2, true),
        (2, 3, true),
        (2, 4, false),
        (4, 2, false),
        (3, 4, true),
        (4, 3, true)
    ]
    for (i, j, e) in expected
        @test BEFWM2.share_prey(i, j, foodweb_5links) == e
    end
end

@testset "Find number of resources of each species." begin
    @test BEFWM2.number_of_resource(foodweb_2links) == [0, 0, 1, 1]
    @test BEFWM2.number_of_resource(foodweb_3links) == [0, 0, 2, 1]
    @test BEFWM2.number_of_resource(foodweb_5links) == [0, 1, 3, 1]
end
