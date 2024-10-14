@testset "Metabolic class component." begin

    base = Model(Foodweb([:a => :b, :b => :c]))
    m = base + MetabolicClass([:i, :e, :p])

    @test m.metabolic_classes == [:invertebrate, :ectotherm, :producer]

    # Default to homogeneous classes.
    m = base + MetabolicClass(:all_ectotherms)
    @test m.metabolic_classes == [:ectotherm, :ectotherm, :producer]
    m = base + MetabolicClass(:all_invertebrates)
    @test m.metabolic_classes == [:invertebrate, :invertebrate, :producer]

    # Consistency checks.
    @sysfails(
        base + MetabolicClass(:invalid_favor),
        Check(
            early,
            [MetabolicClass.Favor],
            "Invalid symbol received for 'favourite': :invalid_favor. \
             Expected either :all_invertebrates or :all_ectotherms instead.",
        )
    )

    @sysfails(
        base + MetabolicClass([:i, :x]),
        Check(
            early,
            [MetabolicClass.Raw],
            "Failed check on class input 2: \
             In aliasing system for \"metabolic class\": \
             Invalid reference: 'x'.",
        )
    )

    # Checked against the foodweb.
    @sysfails(
        base + MetabolicClass([:p, :e, :i]),
        Check(
            late,
            [MetabolicClass.Raw],
            "Metabolic class for species :a cannot be 'p' since it is a consumer.",
        )
    )

    @sysfails(
        base + MetabolicClass([:i, :e, :inv]),
        Check(
            late,
            [MetabolicClass.Raw],
            "Metabolic class for species :c cannot be 'inv' since it is a producer.",
        )
    )

    # Requires a foodweb to be checked against.
    @sysfails(
        Model(MetabolicClass([:i, :e, :p])),
        Missing(Foodweb, MetabolicClass, [MetabolicClass.Raw], nothing),
    )

end
