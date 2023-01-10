# Basic pipeline:
# if a new change is implemented and break this test
# warn all the contributors of this change.
@testset "Basic pipeline." begin
    fw = FoodWeb([0 0 0; 1 0 0; 0 1 0])
    p = ModelParameters(fw)
    B0 = [0.5, 0.5, 0.5]
    sol = simulates(p, B0)
    @test sol[end] ≈ [0.22059687801237501, 0.1890242584230083, 0.04885048633720308]
end
