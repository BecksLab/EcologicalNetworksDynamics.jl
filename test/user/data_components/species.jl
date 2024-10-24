@testset "Species components." begin

    base = Model()

    # From names.
    sp = Species([:a, :b, :c])
    m = base + sp
    @test m.richness == 3
    @test m.S == 3
    @test m.species.richness == 3
    @test m.species.number == 3
    @test m.species.index == Dict(:a => 1, :b => 2, :c => 3)
    @test m.species.names == [:a, :b, :c]
    @test typeof(sp) == Species.Names

    # Get a closure to convert index to label.
    lab = m.species.label
    @test lab(1) == :a
    @test lab.([1, 2, 3]) == [:a, :b, :c]

    # From a number of species (default names generated).
    sp = Species(3)
    m = base + sp
    @test m.species.names == [:s1, :s2, :s3]
    @test typeof(sp) == Species.Number

    #---------------------------------------------------------------------------------------
    # Guards.

    @sysfails(
        Model(Species([:a, :b, :a])),
        Check(late, [Species.Names], "Species 1 and 3 are both named :a."),
    )

    @argfails(
        Model(Species([:a, :b])).species.label(3),
        "Invalid index (3) when there are 2 species names."
    )

    @sysfails(
        Model().richness,
        Property(richness, "Component $(EN._Species) is required to read this property."),
    )

end
