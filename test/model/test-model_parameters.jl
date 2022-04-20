@testset "Model parameters" begin
    A = [0 0 0; 1 0 0; 1 1 0]
    foodweb = FoodWeb(A)

    # Default
    p = ModelParameters(foodweb)
    @test p.BioRates.x == [0, 0.314, 0.314]
    @test p.BioRates.r == [1, 0, 0]
    @test p.Environment.K == [1, nothing, nothing]
    @test p.FoodWeb.A == sparse(A)
    @test typeof(p.FunctionalResponse) == BioenergeticResponse

    # Custom BioRates
    p = ModelParameters(foodweb, BioRates=BioRates(foodweb, x=1))
    @test p.BioRates.x == [1, 1, 1] # changed
    @test p.BioRates.r == [1, 0, 0] # unchanged
    @test p.Environment.K == [1, nothing, nothing] # unchanged
    @test p.FoodWeb.A == sparse(A) # unchanged
    @test typeof(p.FunctionalResponse) == BioenergeticResponse # unchanged

    # Classic Functional Response
    p = ModelParameters(foodweb, FunctionalResponse=ClassicResponse(foodweb))
    @test p.BioRates.x == [0, 0.314, 0.314] # unchanged
    @test p.BioRates.r == [1, 0, 0] # unchanged
    @test p.Environment.K == [1, nothing, nothing] # unchanged
    @test p.FoodWeb.A == sparse(A) # unchanged
    @test typeof(p.FunctionalResponse) == ClassicResponse # changed
end
