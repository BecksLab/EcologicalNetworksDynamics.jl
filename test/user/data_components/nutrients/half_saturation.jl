FR = EN.Nutrients.HalfSaturationFromRawValues

@testset "Nutrients half-saturation component." begin

    # Adapted from concentration.

    fw = Foodweb([:a => [:b, :c]])
    base = Model(fw, Nutrients.Nodes(3))

    hs = Nutrients.HalfSaturation([
        1 2 3
        4 5 6
    ])
    m = base + hs
    @test m.nutrients_half_saturation == [
        1 2 3
        4 5 6
    ]
    @test typeof(hs) === FR

    @sysfails(
        base + Nutrients.HalfSaturation([
            0 1
            3 0
        ]),
        Check(FR),
        "Invalid size for parameter 'h': expected (2, 3), got (2, 2).",
    )

    # Implies nutrients component.
    base = Model(fw)
    m = base + Nutrients.HalfSaturation([
        1 2 3
        4 5 6
    ])
    @test m.nutrients_names == [:n1, :n2, :n3]

    # Unless we can't infer it.
    @sysfails(
        base + Nutrients.HalfSaturation(5),
        Check(FR),
        "missing a required component '$(Nutrients.Nodes)': implied."
    )

end
