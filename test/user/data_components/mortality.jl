FR = MortalityFromRawValues
FA = MortalityFromAllometry

@testset "Mortality component." begin

    # Mostly duplicated from Growth.

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    mr = Mortality([1, 2, 3])
    m = base + mr
    @test m.mortality == [1, 2, 3] == m.d
    @test typeof(mr) === FR

    mr = Mortality([:c => 4, :b => 5, :a => 6])
    m = base + mr
    @test m.mortality == m.d == [6, 5, 4]
    @test typeof(mr) === FR

    mr = Mortality(7)
    m = base + mr
    @test m.mortality == m.d == [7, 7, 7]
    @test typeof(mr) === FR

    # Forbid missing values.
    @sysfails(
        base + Mortality([1, 2]),
        Check(FR),
        "Invalid size for parameter 'd': expected (3,), got (2,)."
    )
    @sysfails(
        base + Mortality([:a => 1]),
        Check(FR),
        "Missing 'species' node label in 'd': no value specified for :b."
    )

    # Implies species component.
    m = Model(Mortality([1, 2, 3]))
    @test m.species_names == [:s1, :s2, :s3]

    m = Model(Mortality([:a => 1, :b => 2, :c => 3]))
    @test m.species_names == [:a, :b, :c]

    # Unless we can't infer it.
    @sysfails(
        Model(Mortality(5)),
        Check(FR),
        "missing required component '$Species': implied."
    )

    #---------------------------------------------------------------------------------------
    # Construct from allometric rates.

    # Make expected results less trivial than with M = 1.
    base += BodyMass(1.5) + MetabolicClass(:all_invertebrates)

    g = Mortality(:Miele2019)
    @test typeof(g) == FA
    @test g.allometry[:p][:a] == 0.0138
    @test g.allometry[:p][:b] == -1 / 4
    m = base + g
    @test m.mortality == [0.028373102913349126, 0.028373102913349126, 0.012469707649815859]

end
