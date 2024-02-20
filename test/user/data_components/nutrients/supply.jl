FR = Nutrients.SupplyFromRawValues

@testset "Nutrients supply component." begin

    # Mostly duplicated from nutrients_supply.

    base = Model(Nutrients.Nodes([:a, :b, :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    sp = Nutrients.Supply([1, 2, 3])
    m = base + sp
    @test m.nutrients_supply == [1, 2, 3]
    @test typeof(sp) === FR

    sp = Nutrients.Supply([:c => 4, :b => 5, :a => 6])
    m = base + sp
    @test m.nutrients_supply == [6, 5, 4]
    @test typeof(sp) === FR

    sp = Nutrients.Supply(7)
    m = base + sp
    @test m.nutrients_supply == [7, 7, 7]
    @test typeof(sp) === FR

    # Forbid missing values.
    @sysfails(
        base + Nutrients.Supply([1, 2]),
        Check(FR),
        "Invalid size for parameter 's': expected (3,), got (2,)."
    )
    @sysfails(
        base + Nutrients.Supply([:a => 1]),
        Check(FR),
        "Missing 'nutrient' node label in 's': no value specified for :b."
    )

    # Implies nutrients component.
    m = Model(Nutrients.Supply([1, 2, 3]))
    @test m.nutrients_names == [:n1, :n2, :n3]

    m = Model(Nutrients.Supply([:a => 1, :b => 2, :c => 3]))
    @test m.nutrients_names == [:a, :b, :c]

    # Unless we can't infer it.
    @sysfails(
        Model(Nutrients.Supply(5)),
        Check(FR),
        "missing a required component '$(Nutrients.Nodes)': implied."
    )

end
