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

@testset "Constructors for allometric parameters" begin
    @test DefaultGrowthParams() == AllometricParams(1.0, 0.0, 0.0, -0.25, 0.0, 0.0)
    @test DefaultMetabolismParams() == AllometricParams(0, 0.88, 0.314, 0, -0.25, -0.25)
    @test DefaultMaxConsumptionParams() == AllometricParams(0.0, 4.0, 8.0, 0.0, 0.0, 0.0)
end

@testset "Computing allometric rates" begin
    foodweb.metabolic_class[1] = "unknown class" # introduce wrong class
    @test_throws ArgumentError allometricrate(foodweb, DefaultGrowthParams())
    foodweb.metabolic_class[1] = "producer" # restore class
    customparams = AllometricParams(0, 1, 1, 0, 1, 2)
    @test allometricrate(foodweb, customparams) == [0, 0, 100, 10]
    @test allometricrate(foodweb, DefaultGrowthParams()) == [1, 1, 0, 0]
    @test allometricrate(foodweb, DefaultMetabolismParams()) == [0, 0, 0.314 * 10^-0.25,
        0.88 * 10^-0.25]
    @test allometricrate(foodweb, DefaultMaxConsumptionParams()) == [0, 0, 8, 4]
end
