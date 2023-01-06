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
    test_on_iterable_pair(pair_tuple, expected_A; quiet = true)

    # Labels
    pair_tuple = (:b => [:b, :c], :c => [:c, :d], :a => :b)
    expected_names = ["a", "b", "c", "d"]
    test_on_iterable_pair(
        pair_tuple,
        expected_A;
        expected_names = expected_names,
        quiet = true,
    )

    # For labels, we can mix Symbols and Strings
    pair_tuple = (:b => [:b, :c], "c" => [:c, "d"], :a => "b")
    test_on_iterable_pair(
        pair_tuple,
        expected_A;
        expected_names = expected_names,
        quiet = true,
    )

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

@testset "FoodWebs from structural model." begin
    n_rep = 20
    SL_tuple = [(10, 20), (15, 20), (15, 30), (20, 50)]
    for model in [nichemodel, nestedhierarchymodel, cascademodel]
        for (S, L) in SL_tuple
            for tL in 0:3
                # From number of links (L)
                n_link_vec = [n_links(FoodWeb(model, S; L = L, tol = tL)) for i in 1:n_rep]
                @test all((L - tL) .<= n_link_vec .<= (L + tL))
                # From connectance (C)
                tC = tL / S^2
                C = L / S^2
                c_vec = [
                    BEFWM2.connectance(FoodWeb(model, S; C = C, tol = tC)) for i in 1:n_rep
                ]
                @test all((C - tC) .<= c_vec .<= (C + tC))
            end
        end
    end
end

@testset "Warning if foodweb has cycle(s) or disconnected species." begin
    A_throwing_warning = [
        [1 => 1], # self-loop is a cycle
        [0 0 0; 1 0 0; 0 0 0], # species 3 is disconnected
        [0 1; 1 0], # loop of length > 1
    ]
    for A in A_throwing_warning
        @test_logs (:warn,) FoodWeb(A) # warning expected
        @test_logs FoodWeb(A, quiet = true) # 'quiet' arg silent the warning
    end

    A_no_warning = [[0 0; 1 0], [0 0 0; 1 0 0; 0 1 0], [2 => 1, 3 => [1, 2]]]
    for A in A_no_warning
        @test_logs FoodWeb(A)
    end
end
