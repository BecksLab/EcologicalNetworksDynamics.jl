NTI = EN.NontrophicInteractions
FR = NTI.RefugeTopologyFromRawEdges
RD = NTI.RandomRefugeTopology

@testset "Refuge layer." begin

    using .NontrophicInteractions

    base = Model(Foodweb([:a => [:b, :c], :b => :d]))

    # ======================================================================================
    # Layer topology.

    # Query potential links.
    @test base.potential_refuge_links == [
        0 0 0 0
        0 0 0 0
        0 1 0 1
        0 1 1 0
    ]
    @test base.n_potential_refuge_links == 4

    #---------------------------------------------------------------------------------------
    # Construct from raw edges.

    cl = RefugeTopology(; A = [
        0 0 0 0
        0 0 0 0
        0 1 0 1
        0 0 1 0
    ])
    m = base + cl
    @test m.refuge_links == [
        0 0 0 0
        0 0 0 0
        0 1 0 1
        0 0 1 0
    ]

    # Alternate adjacency input.
    @test m.refuge_links ==
          get_refuge_links(base + RefugeTopology(; A = [:c => [:b, :d], :d => :c]))
    @test typeof(cl) === FR

    # Can't specify outside potential links.
    @sysfails(
        base + RefugeTopology(; A = [
            1 0 0 0
            1 0 0 0
            1 0 0 0
            0 1 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'A' at edge index [1, 1] (true), \
         but the template for 'potential refuge link' \
         only allows values at the following indices:\n  \
         [(3, 2), (4, 2), (4, 3), (3, 4)]"
    )
    @argfails(RefugeTopology(; A = [], b = 5), "Unexpected argument: b = 5.")

    #---------------------------------------------------------------------------------------
    # Draw random links instead.
    Random.seed!(12)

    # From a number of links.
    cl = RefugeTopology(; L = 2, sym = false)

    # Stochastic expansion!
    m = base + cl
    @test m.refuge_links == [
        0 0 0 0
        0 0 0 0
        0 0 0 0
        0 1 1 0
    ]
    # So, surprisingly:                 /!\
    @test (base + cl).refuge_links != (base + cl).refuge_links

    # Or from connectance.
    m = base + RefugeTopology(; C = 0.5)
    @test m.refuge_links == [
        0 0 0 0
        0 0 0 0
        0 1 0 0
        0 0 1 0
    ]

    @argfails(
        RefugeTopology(; n_links = 3, C = 0.5),
        "Cannot specify both connectance and number of links \
         for drawing random refuge links. \
         Received both 'n_links' argument (3) and 'C' argument (0.5)."
    )
    # Cannot cheat: the above is just a safety guard,
    # but the true, full check happens prior to expansion.
    cl = RefugeTopology(; conn = 3)
    cl.L = 4
    @sysfails(base + cl, Check(RD), "Both 'C' and 'L' specified on blueprint.")
    cl.C = cl.L = nothing
    @sysfails(base + cl, Check(RD), "Neither 'C' or 'L' specified on blueprint.")
    @sysfails(
        base + RefugeTopology(; L = 3, symmetry = true),
        Check(RD),
        "Cannot draw L = 3 links symmetrically: pick an even number instead."
    )
    @sysfails(
        base + RefugeTopology(; L = 5),
        Check(RD),
        "Cannot draw L = 5 refuge links \
         with these 2 producers and 3 preys (max: L = 4)."
    )

    # ======================================================================================
    # Layer data.

    # Intensity.
    ci = RefugeIntensity(5)
    @test ci.phi == 5
    m = base + ci
    @test m.refuge_layer_intensity == 5
    # Modifiable.
    m.refuge_layer_intensity = 8
    @test m.refuge_layer_intensity == 8

    # Functional form.
    cf = RefugeFunctionalForm((x, dx) -> x - dx)
    m = base + cf
    @test m.refuge_layer_functional_form(4, 5) == -1
    # Modifiable.
    m.refuge_layer_functional_form = (x, dx) -> x + dx
    @test m.refuge_layer_functional_form(4, 5) == 9

    f(x) = "nok"
    @argfails(
        m.refuge_layer_functional_form = f,
        "Refuge layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )
    @sysfails(
        base + RefugeFunctionalForm(f),
        Check(RefugeFunctionalForm),
        "Refuge layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )

    # ======================================================================================
    # Aggregate behaviour component.

    # (this needs more input for some (legacy?) reason)
    base += BodyMass(1) + MetabolicClass(:all_invertebrates)

    cl = RefugeLayer(; topology = [
        0 0 0 0
        0 0 0 0
        0 1 0 1
        0 1 0 0
    ], intensity = 5)
    m = base + cl

    # All components brought at once.
    @test m.n_refuge_links == 3
    @test m.refuge_layer_intensity == 5
    @test m.refuge_layer_functional_form(4, -5) == -1

    # From a number of links.
    cl = RefugeLayer(; A = (L = 3, sym = false), I = 8)

    # Sub-blueprints are all here.
    @test cl.topology.L == 3
    @test cl.topology.symmetry == false
    @test cl.intensity.phi == 8
    @test cl.functional_form.fn(5, -8) == -5 / 7

    # And bring them all.
    m = base + cl
    @test m.n_refuge_links == 3
    @test m.refuge_layer_intensity == 8
    @test m.refuge_layer_functional_form(4, -5) == -1

    @sysfails(
        base + RefugeLayer(),
        Check(RefugeLayer),
        "missing a required component '$RefugeTopology': optionally brought."
    )
    @sysfails(
        base + RefugeLayer(; A = (L = 4, sym = true), F = nothing),
        Check(RefugeLayer),
        "missing required component '$RefugeFunctionalForm': optionally brought."
    )

end
