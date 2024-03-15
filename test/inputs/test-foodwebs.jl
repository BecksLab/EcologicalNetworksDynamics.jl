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
    pair_tuple = (:b => [:b, :c], :c => [:c, :d], :a => :b)
    expected_names = ["a", "b", "c", "d"]
    test_on_iterable_pair(pair_tuple, expected_A; expected_names = expected_names)

    # For labels, we can mix Symbols and Strings
    pair_tuple = (:b => [:b, :c], "c" => [:c, "d"], :a => "b")
    test_on_iterable_pair(pair_tuple, expected_A; expected_names = expected_names)

    # Provide labels for the index used. Order matters.
    species = [:mussel, :crab]
    pairs = [2 => 1]
    expected_A = [0 0; 1 0]
    test_on_iterable_pair(
        pairs,
        expected_A;
        expected_names = String.(species),
        species = species,
    )

    # Don't provide both labels in `species` argument and adjacency list.
    @test_throws ArgumentError FoodWeb([:crab => :mussel]; species = species)

end
