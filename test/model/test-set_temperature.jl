A = [0 0 0; 1 0 0; 0 1 0]
foodweb = FoodWeb(A)
foodweb.metabolic_class = ["producer", "invertebrate", "ectotherm vertebrate"]
foodweb.M = [1.0, 10.0, 10.0]
temp = 303.15 # temperature in Kelvin

@testset "set temperature" begin
    p = ModelParameters(foodweb) # bioenergetic default

    # check FR argument error
    @test_throws ArgumentError set_temperature!(p, temp, ExponentialBA())

    # No temperature response
    set_temperature!(p, temp, NoTemperatureResponse())
    @test p.environment.T == temp
    @test p.temperature_response == NoTemperatureResponse()

    # MP with Classic Response 
    p = ModelParameters(foodweb; functional_response = ClassicResponse(foodweb))

    # Exponential Boltzmann-Arrhenius temperature dependence 
    set_temperature!(p, temp, ExponentialBA())
    @test p.environment.T == temp
    @test p.environment.K == exp_ba_vector_rate(foodweb, temp, exp_ba_carrying_capacity())
    @test p.biorates.r == exp_ba_vector_rate(foodweb, temp, exp_ba_growth())
    @test p.biorates.x == exp_ba_vector_rate(foodweb, temp, exp_ba_metabolism())
    @test p.functional_response.hₜ ==
          exp_ba_matrix_rate(foodweb, temp, exp_ba_handling_time())
    @test p.functional_response.aᵣ ==
          exp_ba_matrix_rate(foodweb, temp, exp_ba_attack_rate())
    @test typeof(p.temperature_response) == ExponentialBA

    @test p.temperature_response.r == exp_ba_growth()
    @test p.temperature_response.x == exp_ba_metabolism()
    @test p.temperature_response.aᵣ == exp_ba_attack_rate()
    @test p.temperature_response.hₜ == exp_ba_handling_time()
    @test p.temperature_response.K == exp_ba_carrying_capacity()
end
