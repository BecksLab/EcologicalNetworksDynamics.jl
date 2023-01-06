@testset "Extended methods from Graphs.jl" begin
    A1 = [0 0; 1 0] # cyclic: 0 | connected: 1
    A2 = [0 1; 1 0] # cyclic: 1 | connected: 1
    A3 = [1 0; 0 0] # cyclic: 1 | connected: 0 (self-loop is a loop)
    A4 = [0 1 0; 1 0 0; 0 0 0] # cyclic: 1 | connected: 0
    A5 = [0 1 0; 1 0 0; 1 0 0] # cyclic: 1 | connected: 1
    A_list = [A1, A2, A3, A4, A5]
    fw_list = FoodWeb.(A_list, quiet = true)
    extended_functions = [BEFWM2.is_cyclic, BEFWM2.is_connected]
    expected_cyclic = [0, 1, 1, 1, 1]
    expected_connected = [1, 1, 0, 0, 1]
    expected = hcat(expected_cyclic, expected_connected)
    evaluated = -ones(length(fw_list), length(extended_functions))
    for (i, fw) in enumerate(fw_list), (j, f) in enumerate(extended_functions)
        evaluated[i, j] = f(fw)
    end
    @test expected == evaluated
end
