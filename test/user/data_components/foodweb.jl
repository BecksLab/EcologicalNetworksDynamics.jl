@testset "Foodweb component." begin
    # Very structuring, the foodweb does provide a lot of properties.

    # Can be used as a first component.
    fw = Foodweb([:a => [:b, :c], :b => :c])
    m = Model(fw)

    # Species component is automatically brought.
    @test m.S == 3
    @test m.species_names == [:a, :b, :c]

    #---------------------------------------------------------------------------------------
    # Properties brought by the foodweb.

    @test m.trophic_links == m.A == [
        0 1 1
        0 0 1
        0 0 0
    ]
    @test m.n_trophic_links == 3
    @test m.trophic_levels == [2.5, 2.0, 1.0]

    # Either query with indices or species name.
    @test m.trophic_levels[2] == 2
    @test m.trophic_levels[:b] == 2
    @viewfails(
        m.trophic_levels[:x],
        EN.TrophicLevels,
        "Invalid species node label. \
         Expected either :a, :b or :c, got instead: :x."
    )

    #---------------------------------------------------------------------------------------
    # Producers/consumer data is deduced from the foodweb.

    @test m.producers_mask == Bool[0, 0, 1]
    @test m.consumers_mask == Bool[1, 1, 0]
    @test m.preys_mask == Bool[0, 1, 1]
    @test m.tops_mask == Bool[1, 0, 0]
    @test m.n_producers == 1
    @test m.n_consumers == 2
    @test m.n_preys == 2
    @test m.n_tops == 1

    @test is_consumer(m, 2)
    @test is_consumer(m, :b) # Equivalent.
    @test is_producer(m, :c)
    @test is_prey(m, :b)
    @test is_top(m, :a)

    @test collect(m.producers_indices) == [3]
    @test collect(m.consumers_indices) == [1, 2]
    @test collect(m.preys_indices) == [2, 3]
    @test collect(m.tops_indices) == [1]

    @test m.producers_sparse_index == Dict(:c => 3)
    @test m.producers_dense_index == Dict(:c => 1)
    @test m.consumers_sparse_index == Dict(:a => 1, :b => 2)
    @test m.consumers_dense_index == Dict(:a => 1, :b => 2)
    @test m.preys_sparse_index == Dict(:b => 2, :c => 3)
    @test m.preys_dense_index == Dict(:b => 1, :c => 2)
    @test m.tops_sparse_index == Dict(:a => 1)
    @test m.tops_dense_index == Dict(:a => 1)

    #---------------------------------------------------------------------------------------
    # Higher-level links info.

    m = Model(Foodweb([2 => [1, 3], 4 => [2, 3]]))

    @test m.trophic_links == [
        0 0 0 0
        1 0 1 0
        0 0 0 0
        0 1 1 0
    ]

    @test m.producers_links == [
        1 0 1 0
        0 0 0 0
        1 0 1 0
        0 0 0 0
    ]

    @test m.herbivorous_links == [
        0 0 0 0
        1 0 1 0
        0 0 0 0
        0 0 1 0
    ]

    @test m.carnivorous_links == [
        0 0 0 0
        0 0 0 0
        0 0 0 0
        0 1 0 0
    ]

end
