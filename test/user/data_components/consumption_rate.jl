FR = ConsumptionRateFromRawValues

@testset "Consumption rate component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    cr = ConsumptionRate([:a => 1, :b => 2])
    m = base + cr
    @test m.consumption_rate == [1, 2, 0]
    @test typeof(cr) === FR

    # Only consumers indices allowed.
    @sysfails(
        base + ConsumptionRate([:c => 3]),
        Check(FR),
        "Invalid 'consumers' node label in 'alpha'. \
         Expected either :a or :b, got instead: :c."
    )

    cr = ConsumptionRate([4, 5, 0])
    m = base + cr
    a = m.consumption_rate._ref
    @test m.consumption_rate == [4, 5, 0]
    @test typeof(cr) === FR

    # Only consumers values allowed.
    @sysfails(
        base + ConsumptionRate([6, 7, 8]),
        Check(FR),
        "Non-missing value found for 'alpha' at node index [3] (8.0), \
         but the template for 'consumers' only allows values \
         at the following indices:\n  [1, 2]"
    )

end
