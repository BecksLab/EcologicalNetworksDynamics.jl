@testset "GrowthRate component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    gr = GrowthRate([:c => 3])
    m = base + gr
    @test m.growth_rate == [0, 0, 3] == m.r
    @test typeof(gr) === FR

    # Only producers indices allowed.
    @sysfails(
        base + GrowthRate([:a => 1]),
        Check(FR),
        "Invalid 'producers' node label in 'r'. Expected :c, got instead: :a."
    )

    gr = GrowthRate([0, 0, 4])
    m = base + gr
    @test m.growth_rate == [0, 0, 4] == m.r
    @test typeof(gr) === FR

    # Only producers values allowed.
    @sysfails(
        base + GrowthRate([4, 5, 7]),
        Check(FR),
        "Non-missing value found for 'r' at node index [1] (4.0), \
         but the template for 'producers' only allows values \
         at the following indices:\n  [3]"
    )

    #---------------------------------------------------------------------------------------
    # Construct from allometric rates.

    base += BodyMass(; Z = 1) + MetabolicClass(:all_invertebrates)

    gr = GrowthRate(:Miele2019)
    @test typeof(gr) == FA
    @test gr.allometry[:p][:a] == 1
    @test gr.allometry[:p][:b] == -1 / 4

    # Alternative explicit input.
    @test gr == GrowthRateFromAllometry(; a_p = 1, b_p = -0.25)

    m = base + gr
    @test m.growth_rate == [0, 0, 1]

    # Forbid unnecessary allometric parameters.
    @sysfails(
        base + GrowthRateFromAllometry(; p = (a = 1, b = 0.25, c = 8)),
        Check(FA),
        "Allometric parameter 'c' (target_exponent) for 'producer' \
         is meaningless in the context of calculating growth rates: 8.0."
    )
    @sysfails(
        base + GrowthRateFromAllometry(; p = (a = 1, b = 0.25), i_a = 8),
        Check(FA),
        "Allometric rates for 'invertebrate' \
         are meaningless in the context of calculating growth rates: (a: 8.0)."
    )

    #---------------------------------------------------------------------------------------
    # Construct from temperature.

    gr = GrowthRate(:Binzer2016)
    @test typeof(gr) == FT
    @test gr.E_a == -0.84 # This one also has an activation energy.
    @test gr.allometry == Allometry(; p = (a = 1.5497531357028967e-7, b = -1 / 4))

    # Alternative explicit input.
    @test gr == GrowthRateFromTemperature(-0.84; p_a = 1.5497531357028967e-7, p_b = -1 / 4)

    m = base + Temperature(298.5) + gr
    @test m.growth_rate == [0, 0, 2.812547966878026e-7]

    # Forbid if no temperature is available.
    @sysfails(
        base + gr,
        Check(FT),
        "blueprint cannot expand without component '$Temperature'."
    )

end
