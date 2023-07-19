FR = HalfSaturationDensityFromRawValues

@testset "Half-saturation density component." begin

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    hd = HalfSaturationDensity([:a => 1, :b => 2])
    m = base + hd
    @test m.half_saturation_density == [1, 2, 0]
    @test typeof(hd) === FR

    # Only consumers indices allowed.
    @sysfails(
        base + HalfSaturationDensity([:c => 3]),
        Check(FR),
        "Invalid 'consumers' node label in 'B0'. \
         Expected either :a or :b, got instead: :c."
    )

    hd = HalfSaturationDensity([4, 5, 0])
    m = base + hd
    a = m.half_saturation_density._ref
    @test m.half_saturation_density == [4, 5, 0]
    @test typeof(hd) === FR

    # Only consumers values allowed.
    @sysfails(
        base + HalfSaturationDensity([6, 7, 8]),
        Check(FR),
        "Non-missing value found for 'B0' at node index [3] (8.0), \
         but the template for 'consumers' only allows values \
         at the following indices:\n  [1, 2]"
    )

end
