@testset "Environment" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0])
    environment = Environment(foodweb) # default
    @test environment.K == [1, nothing, nothing]
    @test environment.T == 293.15
    environment = Environment(foodweb, K=10) # change K for producers (homogeneous)
    @test environment.K == [10, nothing, nothing]
    environment = Environment(foodweb, K=[10, 1, nothing]) # change K for producers (vec)
    @test environment.K == [10, 1, nothing]
    environment = Environment(foodweb, T=300) # increase temperature
    @test environment.T == 300
end
