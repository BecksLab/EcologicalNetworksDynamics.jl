NTI = EN.NontrophicInteractions
FR = NTI.InterferenceTopologyFromRawEdges
RD = NTI.RandomInterferenceTopology

@testset "Interference layer." begin

    using .NontrophicInteractions

    base = Model(Foodweb([:a => [:b, :c], :b => :c, :d => [:b, :a]]))

    # ======================================================================================
    # Layer topology.

    # Query potential links.
    @test base.potential_interference_links == [
        0 1 0 1
        1 0 0 0
        0 0 0 0
        1 0 0 0
    ]
    @test base.n_potential_interference_links == 4

    #---------------------------------------------------------------------------------------
    # Construct from raw edges.

    cl = InterferenceTopology(; A = [
        0 0 0 1
        1 0 0 0
        0 0 0 0
        1 0 0 0
    ])
    m = base + cl
    @test m.interference_links == [
        0 0 0 1
        1 0 0 0
        0 0 0 0
        1 0 0 0
    ]

    # Alternate adjacency input.
    @test m.interference_links == get_interference_links(
        base + InterferenceTopology(; A = [:a => :d, :b => :a, :d => :a]),
    )
    @test typeof(cl) === FR

    # Can't specify outside potential links.
    @sysfails(
        base + InterferenceTopology(; A = [
            1 0 0 0
            1 0 0 0
            1 0 0 0
            0 1 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'A' at edge index [1, 1] (true), \
         but the template for 'potential interference link' \
         only allows values at the following indices:\n  \
         [(2, 1), (4, 1), (1, 2), (1, 4)]"
    )
    @argfails(InterferenceTopology(; A = [], b = 5), "Unexpected argument: b = 5.")

    #---------------------------------------------------------------------------------------
    # Draw random links instead.
    Random.seed!(12)

    # From a number of links.
    cl = InterferenceTopology(; L = 2, sym = false)

    # Stochastic expansion!
    m = base + cl
    @test m.interference_links == [
        0 1 0 0
        0 0 0 0
        0 0 0 0
        1 0 0 0
    ]
    # So, surprisingly:                 /!\
    @test (base + cl).interference_links != (base + cl).interference_links

    # Or from connectance.
    m = base + InterferenceTopology(; C = 0.5)
    @test m.interference_links == [
        0 1 0 0
        1 0 0 0
        0 0 0 0
        0 0 0 0
    ]

    @argfails(
        InterferenceTopology(; n_links = 3, C = 0.5),
        "Cannot specify both connectance and number of links \
         for drawing random interference links. \
         Received both 'n_links' argument (3) and 'C' argument (0.5)."
    )
    # Cannot cheat: the above is just a safety guard,
    # but the true, full check happens prior to expansion.
    cl = InterferenceTopology(; conn = 3)
    cl.L = 4
    @sysfails(base + cl, Check(RD), "Both 'C' and 'L' specified on blueprint.")
    cl.C = cl.L = nothing
    @sysfails(base + cl, Check(RD), "Neither 'C' or 'L' specified on blueprint.")
    @sysfails(
        base + InterferenceTopology(; L = 3, symmetry = true),
        Check(RD),
        "Cannot draw L = 3 links symmetrically: pick an even number instead."
    )
    @sysfails(
        base + InterferenceTopology(; L = 6),
        Check(RD),
        "Cannot draw L = 6 interference links \
         with these 3 consumers and 3 preys (max: L = 4)."
    )

    # ======================================================================================
    # Layer data.

    # Intensity.
    ci = InterferenceIntensity(5)
    @test ci.psi == 5
    m = base + ci
    @test m.interference_layer_intensity == 5
    # Modifiable.
    m.interference_layer_intensity = 8
    @test m.interference_layer_intensity == 8

    # ======================================================================================
    # Aggregate behaviour component.

    # (this needs more input for some (legacy?) reason)
    base += BodyMass(1) + MetabolicClass(:all_invertebrates)

    cl = InterferenceLayer(; topology = [
        0 1 0 0
        1 0 0 0
        0 0 0 0
        1 0 0 0
    ], intensity = 5)
    m = base + cl

    # All components brought at once.
    @test m.n_interference_links == 3
    @test m.interference_layer_intensity == 5

    # From a number of links.
    cl = InterferenceLayer(; A = (L = 3, sym = false), I = 8)

    # Sub-blueprints are all here.
    @test cl.topology.L == 3
    @test cl.topology.symmetry == false
    @test cl.intensity.psi == 8

    # And bring them all.
    m = base + cl
    @test m.n_interference_links == 3
    @test m.interference_layer_intensity == 8

    @sysfails(
        base + InterferenceLayer(),
        Check(InterferenceLayer),
        "missing a required component '$InterferenceTopology': optionally brought."
    )

end
