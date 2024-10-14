@testset "Body mass component." begin

    base = Model()

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    bm = BodyMass([1, 2, 3])
    m = base + bm
    # Implies species compartment.
    @test m.richness == 3
    @test m.species.names == [:s1, :s2, :s3]
    @test m.body_masses == [1, 2, 3] == m.M

    # Mapped input.
    bm = BodyMass([:a => 1, :b => 2, :c => 3])
    m = base + bm
    @test m.richness == 3
    @test m.species.names == [:a, :b, :c]
    @test m.body_masses == [1, 2, 3] == m.M

    # Editable property.
    m.body_masses[1] = 2
    m.body_masses[2:3] *= 10
    @test m.body_masses == [2, 20, 30] == m.M

    # All the same mass.
    @test (Model(Species(3)) + BodyMass(2)).body_masses == [2, 2, 2]

    # But the richness needs to be known.
    @sysfails(Model(BodyMass(5)), Missing(Species, BodyMass, [BodyMass.Flat], nothing))

    # Checked.
    @sysfails(
        Model(Species(3)) + BodyMass([1, 2]),
        Check(
            late,
            [BodyMass.Raw],
            "Invalid size for parameter 'M': expected (3,), got (2,).",
        )
    )

    #---------------------------------------------------------------------------------------
    # Construct from Z values and the trophic level.

    fw = Foodweb([:a => [:b, :c], :b => :c])

    bm = BodyMass(; Z = 2.8)

    m = base + fw + bm
    @test m.trophic.levels == [2.5, 2, 1]
    @test m.body_masses == [2.8^1.5, 2.8, 1]

    @sysfails(Model(Species(2)) + bm, Missing(Foodweb, nothing, [BodyMass.Z], nothing))
    @sysfails(
        base + fw + BodyMass(; Z = -1.0),
        Check(
            late,
            [BodyMass.Z],
            "Cannot calculate body masses from trophic levels \
             with a negative value of Z: -1.0.",
        )
    )

    #---------------------------------------------------------------------------------------
    # Check input.

    @argfails(BodyMass(), "Either 'M' or 'Z' must be provided to define body masses.")
    @failswith(BodyMass([1, 2], Z = 3.4), MethodError)
    @failswith((m.M[1] = 'a'), WriteError("not a real number", :body_masses, (1,), 'a'))
    @failswith(
        (m.M[2:3] *= -10),
        WriteError("not a positive value", :body_masses, (2,), -28.0)
    )

end
