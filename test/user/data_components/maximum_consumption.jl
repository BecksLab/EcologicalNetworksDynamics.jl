FR = MaximumConsumptionFromRawValues
FA = MaximumConsumptionFromAllometry

@testset "MaximumConsumption component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    mc = MaximumConsumption([:a => 1, :b => 2])
    m = base + mc
    @test m.maximum_consumption == [1, 2, 0] == m.y
    @test typeof(mc) === FR

    # Only consumers indices allowed.
    @sysfails(
        base + MaximumConsumption([:c => 3]),
        Check(FR),
        "Invalid 'consumers' node label in 'y'. Expected either :a or :b, got instead: :c."
    )

    mc = MaximumConsumption([4, 5, 0])
    m = base + mc
    @test m.maximum_consumption == [4, 5, 0] == m.y
    @test typeof(mc) === FR

    # Only consumers values allowed.
    @sysfails(
        base + MaximumConsumption([6, 7, 8]),
        Check(FR),
        "Non-missing value found for 'y' at node index [3] (8.0), \
         but the template for 'consumers' only allows values \
         at the following indices:\n  [1, 2]"
    )

    #---------------------------------------------------------------------------------------
    # Construct from allometric rates.

    base += BodyMass(; Z = 1) + MetabolicClass(:all_invertebrates)

    mc = MaximumConsumption(:Miele2019)
    @test typeof(mc) == FA
    @test mc.allometry[:i][:a] == 8
    @test mc.allometry[:i][:b] == 0

    m = base + mc
    @test m.maximum_consumption == [8, 8, 0]

    @sysfails(
        base + MaximumConsumptionFromAllometry(; i_c = 1),
        Check(FA),
        "Allometric parameter 'c' (target_exponent) for 'invertebrate' \
         is meaningless in the context of calculating maximum consumption rate: 1.0."
    )

    @sysfails(
        base + MaximumConsumptionFromAllometry(; a_p = 1),
        Check(FA),
        "Allometric rates for 'producer' \
         are meaningless in the context of calculating maximum consumption rate: (a: 1.0)."
    )

end
