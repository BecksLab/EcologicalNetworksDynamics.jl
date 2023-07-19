FR = MetabolismFromRawValues
FA = MetabolismFromAllometry
FT = MetabolismFromTemperature

@testset "Metabolism component." begin

    # Mostly duplicated from Mortality.

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    mb = Metabolism([1, 2, 3])
    m = base + mb
    @test m.metabolism == [1, 2, 3] == m.x
    @test typeof(mb) === FR

    mb = Metabolism([:c => 4, :b => 5, :a => 6])
    m = base + mb
    @test m.metabolism == m.x == [6, 5, 4]
    @test typeof(mb) === FR

    mb = Metabolism(7)
    m = base + mb
    @test m.metabolism == m.x == [7, 7, 7]
    @test typeof(mb) === FR

    @sysfails(
        base + Metabolism([1, 2]),
        Check(FR),
        "Invalid size for parameter 'x': expected (3,), got (2,)."
    )
    @sysfails(
        base + Metabolism([:a => 1]),
        Check(FR),
        "Missing 'species' node label in 'x': no value specified for :b."
    )

    # Implies species component.
    m = Model(Metabolism([1, 2, 3]))
    @test m.species_names == [:s1, :s2, :s3]

    m = Model(Metabolism([:a => 1, :b => 2, :c => 3]))
    @test m.species_names == [:a, :b, :c]

    # Unless we can't infer it.
    @sysfails(
        Model(Metabolism(5)),
        Check(FR),
        "missing required component '$Species': implied."
    )

    #---------------------------------------------------------------------------------------
    # Construct from allometric rates.

    base += BodyMass(1.5) + MetabolicClass(:all_invertebrates)

    mb = Metabolism(:Miele2019)
    @test typeof(mb) == FA
    @test mb.allometry[:i][:a] == 0.314
    @test mb.allometry[:i][:b] == -1 / 4
    m = base + mb
    @test m.metabolism == [0.2837310291334913, 0.2837310291334913, 0.0]

    #---------------------------------------------------------------------------------------
    # Construct from temperature.

    mb = Metabolism(:Binzer2016)
    @test typeof(mb) == FT
    @test mb.E_a == -0.69
    @test mb.allometry[:i][:a] == 6.557967639824989e-8
    @test mb.allometry[:invertebrate][:source_exponent] == -0.31 # Aka. [:i][:b].

    m = base + Temperature(298.5) + mb
    @test m.metabolism == [9.436206283089092e-8, 9.436206283089092e-8, 0.0]

    # Forbid if no temperature is available.
    @sysfails(
        base + mb,
        Check(FT),
        "blueprint cannot expand without component '$Temperature'."
    )

end
