FR = CarryingCapacityFromRawValues
FT = CarryingCapacityFromTemperature

@testset "Carrying capacity component." begin

    # Mostly duplicated from Growth.

    base = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    cc = CarryingCapacity([:c => 3])
    m = base + cc
    @test m.carrying_capacity == [0, 0, 3] == m.K
    @test typeof(cc) === FR

    # Only consumers indices allowed.
    @sysfails(
        base + CarryingCapacity([:a => 1]),
        Check(FR),
        "Invalid 'producers' node label in 'K'. Expected :c, got instead: :a."
    )

    cc = CarryingCapacity([0, 0, 3])
    m = base + cc
    @test m.carrying_capacity == [0, 0, 3] == m.K
    @test typeof(cc) === FR

    # Only consumers values allowed.
    @sysfails(
        base + CarryingCapacity([1, 2, 3]),
        Check(FR),
        "Non-missing value found for 'K' at node index [1] (1.0), \
         but the template for 'producers' only allows values \
         at the following indices:\n  [3]"
    )

    #---------------------------------------------------------------------------------------
    # Construct from temperature.

    base += BodyMass(; Z = 1) + MetabolicClass(:all_invertebrates)

    cc = CarryingCapacity(:Binzer2016)
    @test typeof(cc) == FT
    @test cc.E_a == 0.71
    @test cc.allometry == Allometry(; p = (a = 3, b = 0.28))

    # Alternative explicit input.
    @test cc == CarryingCapacityFromTemperature(0.71; p_a = 3, p_b = 0.28)

    m = base + Temperature(298.5) + cc
    @test m.carrying_capacity == [0, 0, 1.8127671052326149]

    # Forbid if no temperature is available.
    @sysfails(
        base + cc,
        Check(FT),
        "blueprint cannot expand without component '$Temperature'."
    )

end
