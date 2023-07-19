FR = IntraspecificInterferenceFromRawValues

@testset "Half-saturation density component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    ii = IntraspecificInterference([:a => 1, :b => 2])
    m = base + ii
    @test m.intraspecific_interference == [1, 2, 0]
    @test typeof(ii) === FR

    # Only consumers indices allowed.
    @sysfails(
        base + IntraspecificInterference([:c => 3]),
        Check(FR),
        "Invalid 'consumers' node label in 'c'. \
         Expected either :a or :b, got instead: :c."
    )

    ii = IntraspecificInterference([4, 5, 0])
    m = base + ii
    a = m.intraspecific_interference._ref
    @test m.intraspecific_interference == [4, 5, 0]
    @test typeof(ii) === FR

    # Only consumers values allowed.
    @sysfails(
        base + IntraspecificInterference([6, 7, 8]),
        Check(FR),
        "Non-missing value found for 'c' at node index [3] (8.0), \
         but the template for 'consumers' only allows values \
         at the following indices:\n  [1, 2]"
    )

end
