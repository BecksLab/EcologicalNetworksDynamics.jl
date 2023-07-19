FR = EN.AttackRateFromRawValues
FT = AttackRateFromTemperature

@testset "Attack rate component." begin

    # Adapted from handling time.

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    ar = AttackRate([
        0 1 2
        0 0 3
        0 0 0
    ])
    m = base + ar
    @test m.attack_rate == [
        0 1 2
        0 0 3
        0 0 0
    ]
    @test typeof(ar) === FR

    # Adjacency list input.
    m = base + AttackRate([:a => [:b => 1], :b => [:c => 3]])
    @test m.attack_rate == [
        0 1 0
        0 0 3
        0 0 0
    ]

    # Only trophic links indices allowed.
    @sysfails(
        base + AttackRate([
            0 1 2
            3 0 4
            0 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'a_r' at edge index [2, 1] (3.0), \
         but the template for 'trophic link' only allows values \
         at the following indices:\n  [(1, 2), (1, 3), (2, 3)]",
    )
    @sysfails(
        base + AttackRate([:b => [:a => 5]]),
        Check(FR),
        "Invalid 'trophic link' edge label in 'a_r': (:b, :a). \
         Valid edges target labels for source :b in this template are:\n  [:c]",
    )

    # Default from body masses.
    m = base + BodyMass(; Z = 1.5) + AttackRate(:Miele2019)
    @test round.(m.attack_rate) ≈ [
        0 70 66
        0 0 60
        0 0 0
    ]

    @sysfails(
        base + AttackRate(:Miele2019),
        Check(FR),
        "blueprint cannot expand without a component '$BodyMass': \
         Miele2019 method for calculating attack rates \
         requires individual body mass data."
    )

    #---------------------------------------------------------------------------------------
    # Construct from temperature.

    base += BodyMass(; Z = 1) + MetabolicClass(:all_invertebrates)

    ar = AttackRate(:Binzer2016)
    @test typeof(ar) == FT
    @test ar.E_a == -0.38
    @test ar.allometry[:i][:a] == exp(-13.1)
    @test ar.allometry[:e][:c] == -0.8

    m = base + Temperature(298.5) + ar
    a = 2.678153116108099e-6
    @test m.attack_rate == [
        0 a a
        0 0 a
        0 0 0
    ]

    # Forbid if no temperature is available.
    @sysfails(
        base + ar,
        Check(FT),
        "blueprint cannot expand without component '$Temperature'."
    )

end
