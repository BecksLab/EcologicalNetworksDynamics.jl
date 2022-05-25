@testset "Non-trophic Interactions: build MultiplexNetwork." begin

    # Basic structure.
    foodweb = FoodWeb([0 0; 1 0]) # 2 eats 1
    multiplex_net = MultiplexNetwork(foodweb) # default net w/o non-trophic interactions
    @test isempty(multiplex_net.facilitation.nzval)
    @test isempty(multiplex_net.competition.nzval)
    @test isempty(multiplex_net.refuge.nzval)
    @test isempty(multiplex_net.interference.nzval)
    @test multiplex_net.trophic == foodweb.A
    @test multiplex_net.bodymass == foodweb.M
    @test multiplex_net.species_id == foodweb.species

    # Build from connectance.
    foodweb = FoodWeb(nichemodel, 20, C=0.1)
    # - Only facilitation on.
    multiplex_net = MultiplexNetwork(foodweb, C_facilitation=0.5)
    @test !isempty(multiplex_net.facilitation.nzval)
    @test isempty(multiplex_net.competition.nzval)
    @test isempty(multiplex_net.refuge.nzval)
    @test isempty(multiplex_net.interference.nzval)
    # - Refuge and competition on.
    multiplex_net = MultiplexNetwork(foodweb, C_competition=0.5, C_refuge=0.5)
    @test isempty(multiplex_net.facilitation.nzval)
    @test !isempty(multiplex_net.competition.nzval)
    @test !isempty(multiplex_net.refuge.nzval)
    @test isempty(multiplex_net.interference.nzval)
    # - Everything on.
    multiplex_net = MultiplexNetwork(foodweb, C_facilitation=0.5, C_competition=0.5,
        C_refuge=0.5, C_interference=0.5)
    @test !isempty(multiplex_net.facilitation.nzval)
    @test !isempty(multiplex_net.competition.nzval)
    @test !isempty(multiplex_net.refuge.nzval)
    @test !isempty(multiplex_net.interference.nzval)

    # Build with specifying specific non-trophic matrices.
    custom_matrix = zeros(20, 20)
    custom_matrix[4, 5] = 1
    # - Only facilitation.
    multiplex_net = MultiplexNetwork(foodweb, facilitation=custom_matrix)
    @test multiplex_net.facilitation == sparse(custom_matrix)
    @test isempty(multiplex_net.competition.nzval)
    @test isempty(multiplex_net.refuge.nzval)
    @test isempty(multiplex_net.interference.nzval)
    # - Refuge custom, facilitation on.
    multiplex_net = MultiplexNetwork(foodweb, refuge=custom_matrix, C_facilitation=0.5)
    @test multiplex_net.refuge == sparse(custom_matrix)
    @test isempty(multiplex_net.competition.nzval)
    @test !isempty(multiplex_net.facilitation.nzval)
    @test isempty(multiplex_net.interference.nzval)
end

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

    # Competition.
    expect = Set([(1, 2), (2, 1), (1, 3), (3, 1), (2, 3), (3, 2)])
    @test Set(potential_competition_links(foodweb)) == expect

    # Refuge.
    expect = Set([(1, 2), (2, 1), (1, 3), (3, 1), (2, 3), (3, 2)])
    @test Set(potential_refuge_links(foodweb)) == expect
    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 0 0 1 0])
    expect = Set([(1, 2), (2, 1), (1, 3), (2, 3)])
    @test Set(potential_refuge_links(foodweb)) == expect

    # Interference.
    foodweb = FoodWeb([0 0 0 0; 1 0 0 0; 1 0 0 0; 0 0 0 0])
    expect = Set([(2, 3), (3, 2)])
    @test Set(potential_interference_links(foodweb)) == expect
    foodweb = FoodWeb([0 0 0 0; 1 0 0 0; 1 0 0 0; 1 0 0 0])
    expect = Set([(2, 3), (3, 2), (4, 3), (3, 4), (4, 2), (2, 4)])
    @test Set(potential_interference_links(foodweb)) == expect
    foodweb = FoodWeb([0 0 0 0; 1 0 0 0; 0 1 0 0; 1 1 0 0])
    expect = Set([(4, 3), (3, 4), (4, 2), (2, 4)])
    @test Set(potential_interference_links(foodweb)) == expect
end

@testset "Non-trophic Interactions: draw randomly links." begin
    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 0 0 0 0; 1 1 1 0]) # 1, 2 & 3 producers

    # Asymmetric interaction.
    potential_links = potential_facilitation_links(foodweb)
    Lmax = length(potential_links)

    # - From number of links (L).
    for L in 0:9
        drawn_links = draw_asymmetric_links(potential_links, L)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_asymmetric_links(potential_links, -1)
    @test_throws ArgumentError draw_asymmetric_links(potential_links, Lmax + 1)

    # - From connectance (C).
    for L in 1:9
        drawn_links = draw_asymmetric_links(potential_links, L / Lmax)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_asymmetric_links(potential_links, -0.1)
    @test_throws ArgumentError draw_asymmetric_links(potential_links, 1.1)

    # Symmetric interaction.
    potential_links = potential_competition_links(foodweb)
    Lmax = length(potential_links)

    # - From number of links (L).
    for L in 0:2:6
        drawn_links = draw_symmetric_links(potential_links, L)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_symmetric_links(potential_links, -1)
    @test_throws ArgumentError draw_symmetric_links(potential_links, Lmax + 1)

    # - From connectance (C).
    for L in 2:2:6
        drawn_links = draw_symmetric_links(potential_links, L / Lmax)
        @test length(drawn_links) == L
        @test drawn_links ⊆ Set(potential_links)
    end
    @test_throws ArgumentError draw_symmetric_links(potential_links, -0.1)
    @test_throws ArgumentError draw_symmetric_links(potential_links, 1.1)
end

@testset "Non-trophic Interactions: build non-trophic adjacency matrix." begin
    foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 0 0 0 0; 1 1 1 0]) # 1, 2 & 3 producers

    # Asymmetric interaction.
    potential_links = potential_facilitation_links(foodweb)
    Lmax = length(potential_links)

    # - From number of links.
    A = nontrophic_matrix(foodweb, potential_facilitation_links, 5, symmetric=false)
    row, col = findnz(A)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(A.nzval) == 5
    @test subset ⊆ Set(potential_links)

    # - From connectance.
    A = nontrophic_matrix(foodweb, potential_facilitation_links, 6 / Lmax, symmetric=false)
    row, col = findnz(A)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(A.nzval) == 6
    @test subset ⊆ Set(potential_links)

    # Symmetric interaction.
    potential_links = potential_competition_links(foodweb)
    Lmax = length(potential_links)

    # - From number of links.
    A = nontrophic_matrix(foodweb, potential_competition_links, 4, symmetric=true)
    row, col = findnz(A)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(A.nzval) == 4
    @test subset ⊆ Set(potential_links)

    # - From connectance.
    A = nontrophic_matrix(foodweb, potential_competition_links, 6 / Lmax, symmetric=true)
    row, col = findnz(A)
    subset = Set([(row[i], col[i]) for i in 1:length(row)])
    @test length(A.nzval) == 6
    @test subset ⊆ Set(potential_links)
end
