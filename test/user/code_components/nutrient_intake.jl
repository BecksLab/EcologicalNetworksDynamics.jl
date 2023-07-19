@testset "Nutrient intake component." begin

    import .Nutrients as N

    Random.seed!(12)

    base = Model(
        Foodweb(:niche; S = 5, C = 0.2),
        BodyMass(1),
        MetabolicClass(:all_invertebrates),
    )

    # Default blueprints.
    ni = NutrientIntake()
    @test isnothing(ni.nodes) # Don't pick a default number of nodes.
    @test ni.turnover == N.Turnover(0.25)
    @test ni.r.allometry[:p][:a] == 1
    @test ni.supply == N.Supply(10)
    @test ni.concentration == N.Concentration(1)
    @test ni.half_saturation == N.HalfSaturation(1)

    m = base + Nutrients.Nodes(2) + ni
    @test m.nutrients_turnover == [0.25, 0.25]
    @test m.nutrients_supply == [10, 10]
    @test m.nutrients_concentration == ones(3, 2)
    @test m.nutrients_half_saturation == ones(3, 2)

    # Customize sub-blueprints.
    ni = NutrientIntake(; turnover = [1, 2, 3, 4])
    @test ni.turnover == N.Turnover([1, 2, 3, 4])

    # No need to explicitly add nodes since it can be inferred from the above.
    m = base + ni
    @test m.nutrients_names == [:n1, :n2, :n3, :n4]
    @test m.nutrients_turnover == [1, 2, 3, 4]
    @test m.nutrients_supply == [10, 10, 10, 10]
    @test m.nutrients_concentration == ones(3, 4)
    @test m.nutrients_half_saturation == ones(3, 4)

    # Although the number of nodes may be specified/brought by the blueprint.
    m = base + NutrientIntake(2)
    @test m.nutrients_names == [:n1, :n2]
    @test m.nutrients_turnover == [0.25, 0.25]

    m = base + NutrientIntake([:u, :v])
    @test m.nutrients_names == [:u, :v]
    @test m.nutrients_turnover == [0.25, 0.25]

    @test NutrientIntake(2) == NutrientIntake(; nodes = 2)
    @test NutrientIntake([:u, :v]) == NutrientIntake(; nodes = [:u, :v])

    # Watch consistency.
    @sysfails(
        base + Nutrients.Nodes([:a, :b, :c]) + NutrientIntake(; supply = [1, 2]),
        Check(NutrientIntake, N.SupplyFromRawValues),
        "Invalid size for parameter 's': expected (3,), got (2,)."
    )
    @sysfails(
        base + Nutrients.Nodes(3) + NutrientIntake(2),
        Check(NutrientIntake),
        "blueprint also brings '$(Nutrients.Nodes)', which is already in the system."
    )
    @sysfails(
        base + Nutrients.Nodes(3) + NutrientIntake(; turnover = [1, 2]),
        Check(NutrientIntake, Nutrients.TurnoverFromRawValues),
        "Invalid size for parameter 't': expected (3,), got (2,)."
    )
    @sysfails(
        base + NutrientIntake(3; turnover = [1, 2]),
        Check(NutrientIntake, Nutrients.TurnoverFromRawValues),
        "Invalid size for parameter 't': expected (3,), got (2,)."
    )
    @argfails(
        NutrientIntake(3; nodes = 2),
        "Nodes specified once as plain argument (3) and once as keyword argument (nodes = 2)."
    )

end
