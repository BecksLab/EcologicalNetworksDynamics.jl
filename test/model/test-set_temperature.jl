A = [0 0 0; 1 0 0; 0 1 0]
foodweb = FoodWeb(A)
foodweb.metabolic_class = ["producer", "invertebrate", "ectotherm vertebrate"]
foodweb.M = [1.0, 10.0, 10.0]
temp = 303.15 # temperature in Kelvin
p = ModelParameters(foodweb)

@testset "set temperature" begin
    p = ModelParameters(foodweb) # bioenergetic default

    # check FR argument error
    @test_throws ArgumentError set_temperature!(p, temp, ExponentialBA)

    # No temperature response
    set_temperature!(p, temp, NoTemperatureResponse)
    @test p.environment.T == temp
    @test p.temperature_response == NoTemperatureResponse()

    # MP with Classic Response 
    p = ModelParameters(foodweb, functional_response = ClassicResponse(foodweb))

    # Exponential Boltzmann-Arrhenius temperature dependence 
    set_temperature!(p, temp, ExponentialBA)
    @test p.environment.T == temp
    @test p.environment.K == exponentialBA_vector_rate(foodweb, temp, DefaultExpBACarryingCapacityParams())
    @test p.biorates.r == exponentialBA_vector_rate(foodweb, temp, DefaultExpBAGrowthParams())
    @test p.biorates.x == exponentialBA_vector_rate(foodweb, temp, DefaultExpBAMetabolismParams())
    @test p.functional_response.hₜ == exponentialBA_matrix_rate(foodweb, temp, DefaultExpBAHandlingTimeParams())
    @test p.functional_response.aᵣ == exponentialBA_matrix_rate(foodweb, temp, DefaultExpBAAttackRateParams())
    @test p.temperature_response == ExpnentialBA()
end