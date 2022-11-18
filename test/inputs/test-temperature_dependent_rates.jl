A = [0 0 0 0; 0 0 0 0; 1 0 0 0; 0 1 0 0]
foodweb = FoodWeb(A)
foodweb.metabolic_class = ["producer", "producer", "invertebrate", "ectotherm vertebrate"]
foodweb.M = [1.0, 1.0, 10.0, 10.0]
temp = 303.15 # temperature in Kelvin

@testset "Constructors for exponential Boltzmann-Arrhenius parameters" begin
    @test DefaultExpBAGrowthParams() == ExponentialBAParams(exp(-15.68)*4e6, 0, 0, -0.25, -0.25, -0.25, 0, 0, 0, -0.84)
    @test DefaultExpBAMetabolismParams() == ExponentialBAParams(0, exp(-16.54)*4e6 , exp(-16.54)*4e6 , -0.31, -0.31, -0.31, 0, 0, 0, -0.69)
    @test DefaultExpBAHandlingTimeParams() == ExponentialBAParams(0, exp(9.66)*4e6 , exp(9.66)*4e6 , -0.45, -0.45, -0.45, 0.47, 0.47, 0.47, 0.26)
    @test DefaultExpBAAttackRateParams() == ExponentialBAParams(0, exp(-13.1)*4e6 , exp(-13.1)*4e6 , 0.25, 0.25, 0.25, -0.8, -0.8, -0.8, -0.38)
    @test DefaultExpBACarryingCapacityParams() == ExponentialBAParams(exp(10)*4e6, 0, 0, 0.28, 0.28, 0.28, 0, 0, 0, 0.71)
end

@testset "Computing exponential Boltzmann-Arhennius rates" begin
    foodweb.metabolic_class[1] = "unknown class" # introduce wrong class
    @test_throws ArgumentError exponentialBA_vector_rate(foodweb, temp, DefaultExpBAGrowthParams())
    foodweb.metabolic_class[1] = "producer" # restore class
    customparams = ExponentialBAParams(0, 1, 1, 0, 1, 0.5, 1, 1, 2, 0.5)
    ba = exp(0.5 * ((293.15 - temp)/(8.617e-5 * temp * 293.15))) ## boltmann arrhenius term
    @test boltzmann(0.5, temp) == ba
    @test exponentialBA_vector_rate(foodweb, temp, customparams) == [0, 0, 1 * 10.0^0.5 * ba, 1 * 10.0^1 * ba]
    @test exponentialBA_vector_rate(foodweb, temp, DefaultExpBAGrowthParams()) == 
            [(exp(-15.68)* 4e6 * 1^-0.25 * exp(-0.84 * (293.15 - temp)/(8.617e-5 * temp * 293.15))), # a * M^b * boltz
    (exp(-15.68)* 4e6 * 1^-0.25 * exp(-0.84 * (293.15 - temp)/(8.617e-5 * temp * 293.15))), 0, 0]
    @test exponentialBA_vector_rate(foodweb, temp, DefaultExpBAMetabolismParams()) == 
            [0, 0, (exp(-16.54)*4e6 * 1^-0.31 * exp(-0.69 * (293.15 - temp)/(8.617e-5 * temp * 293.15))), 
            (exp(-16.54)*4e6 * 1^-0.31 * exp(-0.69 * (293.15 - temp)/(8.617e-5 * temp * 293.15)))]
    @test exponentialBA_vector_rate(foodweb, temp, DefaultExpBACarryingCapacityParams()) ==
            [(exp(10)*4e6 * 1^0.28 * exp(0.71 * (293.15 - temp)/(8.617e-5 * temp * 293.15))), (exp(10)*4e6 * 1^0.28 * exp(0.71 * (293.15 - temp)/(8.617e-5 * temp * 293.15))), 0, 0]
    @test exponentialBA_matrix_rate(foodweb, temp, customparams) == [0 0 0 0; 0 0 0 0; (1 * 10^0.5 * 1^1 * ba) 0 0 0; 0 (1 * 10^1 * 1^2 * ba) 0 0]
    @test exponentialBA_matrix_rate(foodweb, temp, DefaultExpBAHandlingTimeParams()) ==
            [0 0 0 0; 0 0 0 0; (exp(9.66)*4e6 * 10^-0.45 * 1^0.47 * exp(0.26 * (293.15 - temp)/(8.617e-5 * temp * 293.15))) 0 0 0; 0 (exp(9.66)*4e6 * 10^-0.45 * 10^0.47 * exp(0.26 * (293.15 - temp)/(8.617e-5 * temp * 293.15))) 0 0]
    @test exponentialBA_matrix_rate(foodweb, temp, DefaultExpBAAttackRateParams()) ==
            [0 0 0 0; 0 0 0 0; (exp(-13.1)*4e6 * 10^0.25 * 1^-0.8 * exp(-0.38 * (293.15 - temp)/(8.617e-5 * temp * 293.15))) 0 0 0; 0 (exp(-13.1)*4e6 * 10^0.25 * 10^-0.8 * exp(-0.38 * (293.15 - temp)/(8.617e-5 * temp * 293.15))) 0 0]
end

@testset "Helper functions for exponential BA rate computation" begin
    @test exponentialBAparams_to_vec
end