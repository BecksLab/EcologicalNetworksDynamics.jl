FR = EN.BodyMassFromRawValues
FZ = EN.BodyMassFromZ

@testset "Body mass component." begin

    base = Model()

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    bm = BodyMass([1, 2, 3])
    m = base + bm
    # Implies species compartment.
    @test m.richness == 3
    @test m.species_names == [:s1, :s2, :s3]
    @test m.body_masses == [1, 2, 3] == m.M

    m = base + BodyMass([:a => 1, :b => 2, :c => 3])
    @test m.richness == 3
    @test m.species_names == [:a, :b, :c]
    @test m.body_masses == [1, 2, 3] == m.M

    # Unless we can't infer it.
    @sysfails(
        Model(BodyMass(5)),
        Check(FR),
        "missing required component '$Species': implied."
    )

    # The right blueprint type is picked depending on constructor input.
    @test typeof(bm) == FR

    # Checked.
    @sysfails(
        Model(Species(3)) + BodyMass([1, 2]),
        Check(FR),
        "Invalid size for parameter 'M': expected (3,), got (2,)."
    )

    # All the same mass.
    @test (Model(Species(3)) + BodyMass(2)).body_masses == [2, 2, 2]
    # But the richness needs to be known.
    @sysfails(
        Model() + BodyMass(2),
        Check(FR),
        "missing required component '$Species': implied.",
    )

    #---------------------------------------------------------------------------------------
    # Construct from Z values and the trophic level.

    fw = Foodweb([:s1 => [:s2, :s3], :s2 => :s3])

    bm = BodyMass(; Z = 2.8)

    m = base + fw + bm
    @test m.trophic_levels == [2.5, 2, 1]
    @test m.body_masses == [2.8^1.5, 2.8, 1]

    @sysfails(base + bm, Check(FZ), "missing required component '$Foodweb'.")
    @sysfails(
        base + fw + BodyMass(; Z = -1.0),
        Check(FZ),
        "Cannot calculate body masses from trophic levels \
         with a negative value of Z: -1.0."
    )

    #---------------------------------------------------------------------------------------
    # Check input.

    @argfails(BodyMass(), "Either 'M' or 'Z' must be provided to define body masses.")
    @argfails(
        BodyMass(M = [1, 2], Z = 3.4),
        ["Cannot provide both 'M' and 'Z' to specify body masses."]
    )
    @test BodyMass(; M = [1, 2]) == BodyMass([1, 2])

    @argfails(BodyMass([1, 2]; M = [1, 2]), ["Body masses 'M' specified twice:"])

end
