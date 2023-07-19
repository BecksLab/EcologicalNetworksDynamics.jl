FR = EN.Nutrients.ConcentrationFromRawValues

@testset "Nutrients concentration component." begin

    # Mostly adapted from efficiency.

    fw = Foodweb([:a => [:b, :c]])
    base = Model(fw, Nutrients.Nodes(3))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    cn = Nutrients.Concentration([
        1 2 3
        4 5 6
    ])
    m = base + cn
    @test m.nutrients_concentration == [
        1 2 3
        4 5 6
    ]
    @test typeof(cn) === FR

    # Only valid dimensions allowed.
    @sysfails(
        base + Nutrients.Concentration([
            0 1
            3 0
        ]),
        Check(FR),
        "Invalid size for parameter 'c': expected (2, 3), got (2, 2).",
    )

    # Implies nutrients component.
    base = Model(fw)
    m = base + Nutrients.Concentration([
        1 2 3
        4 5 6
    ])
    @test m.nutrients_names == [:n1, :n2, :n3]

    # Unless we can't infer it.
    @sysfails(
        base + Nutrients.Concentration(5),
        Check(FR),
        "missing required component '$(Nutrients.Nodes)': implied."
    )

end
