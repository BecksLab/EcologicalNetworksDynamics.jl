using Test
using BEFWM2

A = [0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0]
foodweb = FoodWeb(A)
foodweb.metabolic_class = ["producer", "producer", "invertebrate",
    "ectotherm vertebrate"]
foodweb.M = [1.0, 1.0, 10.0, 10.0]

@testset "Identifying metabolic classes" begin
    @test BEFWM2.whoisproducer(foodweb) == [1, 1, 0, 0]
    @test BEFWM2.whoisproducer(foodweb.A) == [1, 1, 0, 0]
    @test BEFWM2.whoisinvertebrate(foodweb) == [0, 0, 1, 0]
    @test BEFWM2.whoisvertebrate(foodweb) == [0, 0, 0, 1]
end
