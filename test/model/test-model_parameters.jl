@testset "Model parameters" begin
    A = [0 0 0; 1 0 0; 1 1 0]
    foodweb = FoodWeb(A)

    # Default
    p = ModelParameters(foodweb)
    @test p.biorates.x == [0, 0.314, 0.314]
    @test p.biorates.r == [1, 0, 0]
    @test p.environment.K == [1, nothing, nothing]
    @test p.foodweb.A == sparse(A)
    @test typeof(p.functional_response) == BioenergeticResponse

    # Custom biorates
    p = ModelParameters(foodweb, biorates=BioRates(foodweb, x=1))
    @test p.biorates.x == [1, 1, 1] # changed
    @test p.biorates.r == [1, 0, 0] # unchanged
    @test p.environment.K == [1, nothing, nothing] # unchanged
    @test p.foodweb.A == sparse(A) # unchanged
    @test typeof(p.functional_response) == BioenergeticResponse # unchanged

    # Classic Functional Response
    p = ModelParameters(foodweb, functional_response=ClassicResponse(foodweb))
    @test p.biorates.x == [0, 0.314, 0.314] # unchanged
    @test p.biorates.r == [1, 0, 0] # unchanged
    @test p.environment.K == [1, nothing, nothing] # unchanged
    @test p.foodweb.A == sparse(A) # unchanged
    @test typeof(p.functional_response) == ClassicResponse # changed
end
