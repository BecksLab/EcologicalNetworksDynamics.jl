A = [0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0]
foodweb_2links = FoodWeb(A)
foodweb_2links.metabolic_class = ["producer", "producer", "invertebrate",
    "ectotherm vertebrate"]
foodweb_2links.M = [1.0, 1.0, 10.0, 10.0]

@testset "Identifying metabolic classes" begin
    @test BEFWM2.whoisproducer(foodweb_2links) == [1, 1, 0, 0]
    @test BEFWM2.whoisproducer(foodweb_2links.A) == [1, 1, 0, 0]
    @test BEFWM2.whoisinvertebrate(foodweb_2links) == [0, 0, 1, 0]
    @test BEFWM2.whoisvertebrate(foodweb_2links) == [0, 0, 0, 1]

    @test BEFWM2.isproducer(foodweb_2links, 1) == true
    @test BEFWM2.isproducer(foodweb_2links, 2) == true
    @test BEFWM2.isproducer(foodweb_2links, 3) == false
    @test BEFWM2.isproducer(foodweb_2links, 4) == false

    foodweb_3links = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 0 0 1 0])
    @test BEFWM2.whoisprey(foodweb_3links) == [1, 1, 1, 0]
    @test BEFWM2.whoispredator(foodweb_3links) == [0, 0, 1, 1]
    @test BEFWM2.whoisprey(foodweb_2links) == [1, 1, 0, 0]
    @test BEFWM2.whoispredator(foodweb_2links) == [0, 0, 1, 1]
end

@testset "Predator sharing prey" begin
    foodweb_5links = FoodWeb([0 0 0 0; 1 0 0 0; 1 1 1 0; 0 0 1 0])
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
        @test BEFWM2.share_prey(foodweb_5links, i, j) == e
    end
end

@testset "Finding resources and consumers" begin
    @test convert(Vector, BEFWM2.resource(1, foodweb_2links)) == [0, 0, 0, 0]
    @test convert(Vector, BEFWM2.resource(2, foodweb_2links)) == [0, 0, 0, 0]
    @test convert(Vector, BEFWM2.resource(3, foodweb_2links)) == [1, 0, 0, 0]
    @test convert(Vector, BEFWM2.resource(4, foodweb_2links)) == [0, 1, 0, 0]

    @test convert(Vector, BEFWM2.consumer(1, foodweb_2links)) == [0, 0, 1, 0]
    @test convert(Vector, BEFWM2.consumer(2, foodweb_2links)) == [0, 0, 0, 1]
    @test convert(Vector, BEFWM2.consumer(3, foodweb_2links)) == [0, 0, 0, 0]
    @test convert(Vector, BEFWM2.consumer(4, foodweb_2links)) == [0, 0, 0, 0]

    dict_ressource = Dict(1 => 0, 2 => 0, 3 => 1, 4 => 1)
    @test BEFWM2.resourcenumber([1, 2, 3, 4], foodweb_2links) == dict_ressource
end
