@testset "Foodwebs from adjacency list." begin
    function test_on_iterable_pair(
        pair_tuple,
        expected_A;
        expected_names = nothing,
        kwargs...,
    )
        pair_vector = [i => j for (i, j) in pair_tuple]
        pair_dict = Dict(pair_vector)
        for pair_iter in [pair_tuple, pair_vector, pair_dict]
            fw = FoodWeb(pair_iter; kwargs...)
            @test fw.A == expected_A
            isnothing(expected_names) || @test fw.species == expected_names
        end
    end

    # Indexes
    pair_tuple = (1 => 2, 2 => [2, 3], 3 => (3, 4))
    expected_A = [0 1 0 0; 0 1 1 0; 0 0 1 1; 0 0 0 0]
    test_on_iterable_pair(pair_tuple, expected_A)

    # Labels
    pair_tuple = (:a => :b, :b => [:b, :c], :c => [:c, :d])
    expected_names = ["a", "b", "c", "d"]
    test_on_iterable_pair(pair_tuple, expected_A; expected_names = expected_names)

    # For labels, we can mix Symbols and Strings
    pair_tuple = (:a => "b", :b => [:b, :c], "c" => [:c, "d"])
    test_on_iterable_pair(pair_tuple, expected_A; expected_names = expected_names)

    # Species names user-provided are not overwrite.
    species = [:crab, :mussel]
    pair_tuple = [:c => :m]
    expected_A = [0 1; 0 0]
    test_on_iterable_pair(
        pair_tuple,
        expected_A;
        expected_names = String.(species),
        species = species,
    )
end
