@testset "Metabolic class component." begin

    base = Model(Foodweb([:a => :b, :b => :c]))

    # From aliased values.
    mc = MetabolicClass([:i, :e, :p])
    m = base + mc
    @test m.metabolic_classes == [:invertebrate, :ectotherm, :producer]
    @test typeof(mc) == MetabolicClass.Raw

    # With an explicit map.
    mc = MetabolicClass([:a => :inv, :b => :ect, :c => :prod])
    m = base + mc
    @test m.metabolic_classes == [:invertebrate, :ectotherm, :producer]
    @test typeof(mc) == MetabolicClass.Map

    # Default to homogeneous classes.
    mc = MetabolicClass(:all_ectotherms)
    m = base + mc
    @test m.metabolic_classes == [:ectotherm, :ectotherm, :producer]
    mc = MetabolicClass(:all_invertebrates)
    m = base + mc
    @test m.metabolic_classes == [:invertebrate, :invertebrate, :producer]
    @test typeof(mc) == MetabolicClass.Favor

    # Editable property.
    m.metabolic_classes[2] = "e" # Conversion on.
    @test m.metabolic_classes == [:invertebrate, :ectotherm, :producer]
    m.metabolic_classes[1:2] .= :inv
    @test m.metabolic_classes == [:invertebrate, :invertebrate, :producer]

    # Consistency checks.
    @sysfails(
        base + MetabolicClass([:i, :x]),
        Check(
            early,
            [MetabolicClass.Raw],
            "Metabolic class input 2: \
             In aliasing system for \"metabolic class\": \
             Invalid reference: 'x'.",
        )
    )

    @sysfails(
        base + MetabolicClass([:a => :i, :b => :x]),
        Check(
            early,
            [MetabolicClass.Map],
            "Metabolic class input :b: \
             In aliasing system for \"metabolic class\": \
             Invalid reference: 'x'.",
        )
    )

    @sysfails(
        base + MetabolicClass(:invalid_favor),
        Check(
            early,
            [MetabolicClass.Favor],
            "Invalid symbol received for 'favourite': :invalid_favor. \
             Expected either :all_invertebrates or :all_ectotherms instead.",
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

    # Edition guards.
    @failswith(
        (m.metabolic_classes[2] = :p),
        WriteError(
            "Metabolic class for species 2 cannot be 'producer' since it is a consumer.",
            :metabolic_classes,
            (2,),
            :p,
        ),
    )
    @failswith(
        (m.metabolic_classes[:c] = :i),
        WriteError(
            "Metabolic class for species 3 cannot be 'invertebrate' since it is a producer.",
            :metabolic_classes,
            (3,),
            :i,
        ),
    )

end
