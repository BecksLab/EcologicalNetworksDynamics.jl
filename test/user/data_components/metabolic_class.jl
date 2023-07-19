@testset "Metabolic class component." begin

    base = Model(Foodweb([1 => 2, 2 => 3]))
    m = base + MetabolicClass([:i, :e, :p])

    @test m.metabolic_classes == [:invertebrate, :ectotherm, :producer]

    # Default to homogeneous classes.
    m = base + MetabolicClass(:all_ectotherms)
    @test m.metabolic_classes == [:ectotherm, :ectotherm, :producer]
    m = base + MetabolicClass(:all_invertebrates)
    @test m.metabolic_classes == [:invertebrate, :invertebrate, :producer]

    # Checked against the foodweb.
    @sysfails(
        base + MetabolicClass([:p, :e, :i]),
        Check(MetabolicClass),
        "Metabolic class for species :s1 cannot be 'p' since it is a consumer."
    )
    @sysfails(
        base + MetabolicClass([:i, :e, :inv]),
        Check(MetabolicClass),
        "Metabolic class for species :s3 cannot be 'inv' since it is a producer."
    )

    # Requires a foodweb to be checked against.
    @sysfails(
        Model(MetabolicClass([:i, :e, :p])),
        Check(MetabolicClass),
        "missing required component '$Foodweb'."
    )

end
