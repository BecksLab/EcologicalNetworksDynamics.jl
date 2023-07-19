FR = EN.ConsumersPreferencesFromRawValues

@testset "Consumers preferences component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    # Ask for default matrix.
    ef = ConsumersPreferences(:homogeneous)
    m = base + ef
    @test m.consumers_preferences == m.w == [
        0 0.5 0.5
        0 0 1
        0 0 0
    ]
    @test typeof(ef) === FR

    # Or construct from raw values.
    ef = ConsumersPreferences([
        0 1 2
        0 0 3
        0 0 0
    ])
    m = base + ef
    @test m.consumers_preferences == m.w == [
        0 1 2
        0 0 3
        0 0 0
    ]
    @test typeof(ef) === FR

    # Only trophic links indices allowed.
    @sysfails(
        base + ConsumersPreferences([
            0 1 2
            3 0 4
            0 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'w' at edge index [2, 1] (3.0), \
         but the template for 'trophic link' only allows values \
         at the following indices:\n  [(1, 2), (1, 3), (2, 3)]",
    )

end
