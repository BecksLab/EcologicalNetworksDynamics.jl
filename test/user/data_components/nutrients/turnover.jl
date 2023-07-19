FR = Nutrients.TurnoverFromRawValues

@testset "Nutrients turnover component." begin

    # Mostly duplicated from nutrients_turnover.

    base = Model(Nutrients.Nodes([:a, :b, :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    tr = Nutrients.Turnover([1, 2, 3])
    m = base + tr
    @test m.nutrients_turnover == [1, 2, 3]
    @test typeof(tr) === FR

    tr = Nutrients.Turnover([:c => 4, :b => 5, :a => 6])
    m = base + tr
    @test m.nutrients_turnover == [6, 5, 4]
    @test typeof(tr) === FR

    tr = Nutrients.Turnover(7)
    m = base + tr
    @test m.nutrients_turnover == [7, 7, 7]
    @test typeof(tr) === FR

    # Forbid missing values.
    @sysfails(
        base + Nutrients.Turnover([1, 2]),
        Check(FR),
        "Invalid size for parameter 't': expected (3,), got (2,)."
    )
    @sysfails(
        base + Nutrients.Turnover([:a => 1]),
        Check(FR),
        "Missing 'nutrient' node label in 't': no value specified for :b."
    )

    # Implies nutrients component.
    m = Model(Nutrients.Turnover([1, 2, 3]))
    @test m.nutrients_names == [:n1, :n2, :n3]

    m = Model(Nutrients.Turnover([:a => 1, :b => 2, :c => 3]))
    @test m.nutrients_names == [:a, :b, :c]

    # Unless we can't infer it.
    @sysfails(
        Model(Nutrients.Turnover(5)),
        Check(FR),
        "missing required component '$(Nutrients.Nodes)': implied."
    )

end
