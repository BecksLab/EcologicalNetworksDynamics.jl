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
    @test_throws ArgumentError allometric_rate(foodweb, DefaultGrowthParams())
    foodweb.metabolic_class[1] = "producer" # restore class
    customparams = AllometricParams(0, 1, 1, 0, 1, 2)
    @test allometric_rate(foodweb, customparams) == [0, 0, 100, 10]
    @test allometric_rate(foodweb, DefaultGrowthParams()) == [1, 1, 0, 0]
    @test allometric_rate(foodweb, DefaultMetabolismParams()) == [0, 0, 0.314 * 10^-0.25,
        0.88 * 10^-0.25]
    @test allometric_rate(foodweb, DefaultMaxConsumptionParams()) == [0, 0, 8, 4]
end

@testset "Helper functions for allometric rate computation" begin
    @test BEFWM2.allometricscale(0, 1, 1) == 0 # 0*1^1 = 0
    @test BEFWM2.allometricscale(1, 2, 10) == 100 # 1*10^2 = 100
    @test BEFWM2.allometricscale(2, 3, 2) == 16 # 2*2^3 = 16
    expected_paramsvec = (a=[1, 1, 2, 3], b=[11, 11, 12, 13])
    allometricparams = AllometricParams(1, 3, 2, 11, 13, 12)
    @test BEFWM2.allometricparams_to_vec(foodweb, allometricparams) == expected_paramsvec
end
