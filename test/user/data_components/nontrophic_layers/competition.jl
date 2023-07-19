NTI = EN.NontrophicInteractions
FR = NTI.CompetitionTopologyFromRawEdges
RD = NTI.RandomCompetitionTopology

@testset "Competition layer." begin

    using .NontrophicInteractions

    base = Model(Foodweb([:a => [:b, :c, :d]]))

    # ======================================================================================
    # Layer topology.

    # Query potential links.
    @test base.potential_competition_links == [
        0 0 0 0
        0 0 1 1
        0 1 0 1
        0 1 1 0
    ]
    @test base.n_potential_competition_links == 6

    #---------------------------------------------------------------------------------------
    # Construct from raw edges.

    cl = CompetitionTopology(; A = [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ])
    m = base + cl
    @test m.competition_links == [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ]

    # Alternate adjacency input.
    @test m.competition_links == get_competition_links(
        base + CompetitionTopology(; A = [:b => :c, :c => [:b, :d], :d => :b]),
    )
    @test typeof(cl) === FR

    # Can't specify outside potential links.
    @sysfails(
        base + CompetitionTopology(; A = [
            1 0 0 0
            1 0 0 0
            1 0 0 0
            0 1 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'A' at edge index [1, 1] (true), \
         but the template for 'potential competition link' \
         only allows values at the following indices:\n  \
         [(3, 2), (4, 2), (2, 3), (4, 3), (2, 4), (3, 4)]"
    )
    @argfails(CompetitionTopology(; A = [], b = 5), "Unexpected argument: b = 5.")

    #---------------------------------------------------------------------------------------
    # Draw random links instead.
    Random.seed!(12)

    # From a number of links.
    cl = CompetitionTopology(; L = 4, sym = false)

    # Stochastic expansion!
    m = base + cl
    @test m.competition_links == [
        0 0 0 0
        0 0 0 1
        0 1 0 1
        0 1 0 0
    ]
    # So, surprisingly:                 /!\
    @test (base + cl).competition_links != (base + cl).competition_links

    # Or from connectance.
    m = base + CompetitionTopology(; C = 0.5)
    @test m.competition_links == [
        0 0 0 0
        0 0 0 1
        0 0 0 1
        0 1 1 0
    ]

    @argfails(
        CompetitionTopology(; n_links = 3, C = 0.5),
        "Cannot specify both connectance and number of links \
         for drawing random competition links. \
         Received both 'n_links' argument (3) and 'C' argument (0.5)."
    )
    # Cannot cheat: the above is just a safety guard,
    # but the true, full check happens prior to expansion.
    cl = CompetitionTopology(; conn = 3)
    cl.L = 4
    @sysfails(base + cl, Check(RD), "Both 'C' and 'L' specified on blueprint.")
    cl.C = cl.L = nothing
    @sysfails(base + cl, Check(RD), "Neither 'C' or 'L' specified on blueprint.")
    @sysfails(
        base + CompetitionTopology(; L = 3, symmetry = true),
        Check(RD),
        "Cannot draw L = 3 links symmetrically: pick an even number instead."
    )
    @sysfails(
        base + CompetitionTopology(; L = 8),
        Check(RD),
        "Cannot draw L = 8 competition links with only 3 producers (max: L = 6)."
    )

    # ======================================================================================
    # Layer data.

    # Intensity.
    ci = CompetitionIntensity(5)
    @test ci.gamma == 5
    m = base + ci
    @test m.competition_layer_intensity == 5
    # Modifiable.
    m.competition_layer_intensity = 8
    @test m.competition_layer_intensity == 8

    # Functional form.
    cf = CompetitionFunctionalForm((x, dx) -> x - dx)
    m = base + cf
    @test m.competition_layer_functional_form(4, 5) == -1
    # Modifiable.
    m.competition_layer_functional_form = (x, dx) -> x + dx
    @test m.competition_layer_functional_form(4, 5) == 9

    f(x) = "nok"
    @argfails(
        m.competition_layer_functional_form = f,
        "Competition layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )
    @sysfails(
        base + CompetitionFunctionalForm(f),
        Check(CompetitionFunctionalForm),
        "Competition layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )

    # ======================================================================================
    # Aggregate behaviour component.

    # (this needs more input for some (legacy?) reason)
    base += BodyMass(1) + MetabolicClass(:all_invertebrates)

    cl = CompetitionLayer(; topology = [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ], intensity = 5)
    m = base + cl

    # All components brought at once.
    @test m.n_competition_links == 4
    @test m.competition_layer_intensity == 5
    @test m.competition_layer_functional_form(4, -5) == 24

    # From a number of links.
    cl = CompetitionLayer(; A = (L = 4, sym = false), I = 8)

    # Sub-blueprints are all here.
    @test cl.topology.L == 4
    @test cl.topology.symmetry == false
    @test cl.intensity.gamma == 8
    @test cl.functional_form.fn(5, -8) == 45

    # And bring them all.
    m = base + cl
    @test m.n_competition_links == 4
    @test m.competition_layer_intensity == 8
    @test m.competition_layer_functional_form(4, -5) == 24

    @sysfails(
        base + CompetitionLayer(),
        Check(CompetitionLayer),
        "missing a required component '$CompetitionTopology': optionally brought."
    )
    @sysfails(
        base + CompetitionLayer(; A = (L = 4, sym = true), F = nothing),
        Check(CompetitionLayer),
        "missing required component '$CompetitionFunctionalForm': optionally brought."
    )

end
