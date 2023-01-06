@testset "Extended methods from Graphs.jl" begin
    expectations = [
        (A = [0 0; 1 0], cyclic = 0, connected = 1),
        (A = [0 1; 1 0], cyclic = 1, connected = 1),
        (A = [1 0; 0 0], cyclic = 1, connected = 0),
        (A = [0 1 0; 1 0 0; 0 0 0], cyclic = 1, connected = 0), # self-loop is a loop
        (A = [0 1 0; 1 0 0; 1 0 0], cyclic = 1, connected = 1),
    ]
    for exp in expectations
        A, expected_cyclic, expected_connected = exp
        fw = FoodWeb(A; quiet = true)
        @test expected_cyclic == BEFWM2.is_cyclic(fw)
        @test expected_connected == BEFWM2.is_connected(fw)
    end
end
