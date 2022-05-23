@testset "Non-trophic Interactions: find potential links." begin

    # Facilitation.
    foodweb = FoodWeb([0 0; 1 0]) # 2 eats 1
    @test Set(potential_facilitation_links(foodweb)) == Set([(2, 1)]) # 2 can facilitate 1

    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers
    expect = Set([(1, 2), (2, 1), (3, 1), (3, 2)])
    @test Set(potential_facilitation_links(foodweb)) == expect

    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 0 0 0 0; 1 1 1 0]) # 1, 2 & 3 producers
    expect = Set([(1, 2), (2, 1), (1, 3), (3, 1), (2, 3), (3, 2), (4, 1), (4, 2), (4, 3)])
    @test Set(potential_facilitation_links(foodweb)) == expect
end

@testset "Non-trophic Interactions: draw randomly links." begin
    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 0 0 0 0; 1 1 1 0]) # 1, 2 & 3 producers
    potential_links = potential_facilitation_links(foodweb)
    Lmax = length(potential_links)

    # From number of links (L).
    for L in 0:9
        drawn_links = draw_links(potential_links, L)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_links(potential_links, -1)
    @test_throws ArgumentError draw_links(potential_links, Lmax + 1)

    # From connectance (C).
    for L in 1:9
        drawn_links = draw_links(potential_links, L / Lmax)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_links(potential_links, -0.1)
    @test_throws ArgumentError draw_links(potential_links, 1.1)
end

@testset "Non-trophic Interactions: build non-trophic adjacency matrix." begin
    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 0 0 0 0; 1 1 1 0]) # 1, 2 & 3 producers
    potential_links = potential_facilitation_links(foodweb)
    Lmax = length(potential_links)

    # From number of links.
    facilitation = nontrophic_matrix(foodweb, potential_facilitation_links, 5)
    row, col = findnz(facilitation)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(facilitation.nzval) == 5
    @test subset ⊆ Set(potential_links)

    # From connectance.
    facilitation = nontrophic_matrix(foodweb, potential_facilitation_links, 6 / Lmax)
    row, col = findnz(facilitation)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(facilitation.nzval) == 6
    @test subset ⊆ Set(potential_links)
end
