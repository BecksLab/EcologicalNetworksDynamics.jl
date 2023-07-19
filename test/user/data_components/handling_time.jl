FR = EN.HandlingTimeFromRawValues
FT = HandlingTimeFromTemperature

@testset "'Handling time' component." begin

    # Adapted from efficiency and carrying capacity.

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    ht = HandlingTime([
        0 1 2
        0 0 3
        0 0 0
    ])
    m = base + ht
    @test m.handling_time == [
        0 1 2
        0 0 3
        0 0 0
    ]
    @test typeof(ht) === FR

    # Adjacency list input.
    m = base + HandlingTime([:a => [:b => 1], :b => [:c => 3]])
    @test m.handling_time == [
        0 1 0
        0 0 3
        0 0 0
    ]

    # Only trophic links indices allowed.
    @sysfails(
        base + HandlingTime([
            0 1 2
            3 0 4
            0 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'h_t' at edge index [2, 1] (3.0), \
         but the template for 'trophic link' only allows values \
         at the following indices:\n  [(1, 2), (1, 3), (2, 3)]",
    )
    @sysfails(
        base + HandlingTime([:b => [:a => 5]]),
        Check(FR),
        "Invalid 'trophic link' edge label in 'h_t': (:b, :a). \
         Valid edges target labels for source :b in this template are:\n  [:c]",
    )

    # Default from body masses.
    m = base + BodyMass(; Z = 1.5) + HandlingTime(:Miele2019)
    @test round.(100 * m.handling_time) ≈ [
        0 17 22
        0 0 25
        0 0 0
    ]

    @sysfails(
        base + HandlingTime(:Miele2019),
        Check(FR),
        "blueprint cannot expand without a component '$BodyMass': \
         Miele2019 method for calculating handling times \
         requires individual body mass data."
    )

    #---------------------------------------------------------------------------------------
    # Construct from temperature.

    base += BodyMass(; Z = 1) + MetabolicClass(:all_invertebrates)

    ht = HandlingTime(:Binzer2016)
    @test typeof(ht) == FT
    @test ht.E_a == 0.26
    @test ht.allometry[:i][:a] == exp(9.66)
    @test ht.allometry[:e][:c] == 0.47

    m = base + Temperature(298.5) + ht
    h = 13036.720443481181
    @test m.handling_time == [
        0 h h
        0 0 h
        0 0 0
    ]

    # Forbid if no temperature is available.
    @sysfails(
        base + ht,
        Check(FT),
        "blueprint cannot expand without component '$Temperature'."
    )

end
