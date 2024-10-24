@testset "Efficiency component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    ef = Efficiency([
        0 1 2
        0 0 3
        0 0 0
    ] / 10)
    m = base + ef
    @test m.efficiency == m.e == [
        0 1 2
        0 0 3
        0 0 0
    ] / 10
    @test typeof(ef) === Efficiency.Raw

    # Adjacency list input.
    m = base + Efficiency([:a => [:b => 0.1], :b => [:c => 0.3]])
    @test m.efficiency == m.e == [
        0 1 0
        0 0 3
        0 0 0
    ] / 10
    @test typeof(ef) == Efficiency.Raw

    # Single value.
    m = base + Efficiency(0.1)

    # Only trophic links indices allowed.
    @sysfails(
        base + Efficiency([
            0 1 2
            3 0 4
            0 0 0
        ] / 10),
        Check(
            late,
            [Efficiency.Raw],
            "Non-missing value found for 'e' at edge index [2, 1] (3.0), \
             but the template for 'trophic link' only allows values \
             at the following indices:\n  [(1, 2), (1, 3), (2, 3)]",
        )
    )
    @sysfails(
        base + Efficiency([:b => [:a => 5]]),
        Check(
            late,
            [Efficiency.Adjacency],
            "Invalid 'trophic link' edge label in 'e': (:b, :a). \
             Valid edges target labels for source :b in this template are:\n  [:c]",
        )
    )

    #---------------------------------------------------------------------------------------
    # Construct from the foodweb.

    ef = Efficiency(:Miele2019; e_herbivorous = 2, e_carnivorous = 4)
    @test typeof(ef) == FM
    m = base + ef
    @test m.efficiency == [
        0 4 2
        0 0 2
        0 0 0
    ]

    # Forbid unused arguments.
    @argfails(Efficiency(:Miele2019; e_other = 5), "Unexpected argument: e_other = 5.")

    # TODO: test imply foodweb.
    @test false
end
