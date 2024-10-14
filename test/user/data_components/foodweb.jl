@testset "Foodweb component." begin
    # Very structuring, the foodweb does provide a lot of properties.

    # Can be used as a first component.
    fw = Foodweb([:a => [:b, :c], :b => :c])
    m = Model(fw)

    # Species component is automatically brought.
    @test m.S == 3
    @test m.species.names == [:a, :b, :c]

    #---------------------------------------------------------------------------------------
    # Properties brought by the foodweb.

    @test m.trophic.matrix == m.A == [
        0 1 1
        0 0 1
        0 0 0
    ]
    @test m.trophic.n_links == 3
    @test m.trophic.levels == [2.5, 2.0, 1.0]

    # Either query with indices or species name.
    @test m.trophic.levels[2] == 2
    @test m.trophic.levels[:b] == 2
    @viewfails(
        m.trophic.levels[:x],
        EN.TrophicLevels,
        "Invalid species node label. \
         Expected either :a, :b or :c, got instead: :x."
    )

    #---------------------------------------------------------------------------------------
    # Producers/consumer data is deduced from the foodweb.

    @test m.producers.mask == Bool[0, 0, 1]
    @test m.consumers.mask == Bool[1, 1, 0]
    @test m.preys.mask == Bool[0, 1, 1]
    @test m.tops.mask == Bool[1, 0, 0]
    @test m.producers.number == 1
    @test m.consumers.number == 2
    @test m.preys.number == 2
    @test m.tops.number == 1

    @test is_consumer(m, 2)
    @test is_consumer(m, :b) # Equivalent.
    @test is_producer(m, :c)
    @test is_prey(m, :b)
    @test is_top(m, :a)

    @test collect(m.producers.indices) == [3]
    @test collect(m.consumers.indices) == [1, 2]
    @test collect(m.preys.indices) == [2, 3]
    @test collect(m.tops.indices) == [1]

    @test m.producers.sparse_index == Dict(:c => 3)
    @test m.producers.dense_index == Dict(:c => 1)
    @test m.consumers.sparse_index == Dict(:a => 1, :b => 2)
    @test m.consumers.dense_index == Dict(:a => 1, :b => 2)
    @test m.preys.sparse_index == Dict(:b => 2, :c => 3)
    @test m.preys.dense_index == Dict(:b => 1, :c => 2)
    @test m.tops.sparse_index == Dict(:a => 1)
    @test m.tops.dense_index == Dict(:a => 1)

    #---------------------------------------------------------------------------------------
    # Higher-level links info.

    m = Model(Foodweb([2 => [1, 3], 4 => [2, 3]]))

    @test m.trophic.matrix == [
        0 0 0 0
        1 0 1 0
        0 0 0 0
        0 1 1 0
    ]

    @test m.producers.matrix == [
        1 0 1 0
        0 0 0 0
        1 0 1 0
        0 0 0 0
    ]

    @test m.trophic.herbivory_matrix == [
        0 0 0 0
        1 0 1 0
        0 0 0 0
        0 0 1 0
    ]

    @test m.trophic.carnivory_matrix == [
        0 0 0 0
        0 0 0 0
        0 0 0 0
        0 1 0 0
    ]

end
