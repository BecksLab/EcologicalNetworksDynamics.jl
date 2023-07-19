NTI = EN.NontrophicInteractions
FR = NTI.FacilitationTopologyFromRawEdges
RD = NTI.RandomFacilitationTopology

@testset "Facilitation layer." begin

    # Copied and adapted from competition.

    using .NontrophicInteractions

    base = Model(Foodweb([:a => [:b, :c, :d]]))

    # ======================================================================================
    # Layer topology.

    # Query potential links.
    @test base.potential_facilitation_links == [
        0 1 1 1
        0 0 1 1
        0 1 0 1
        0 1 1 0
    ]
    @test base.n_potential_facilitation_links == 9

    #---------------------------------------------------------------------------------------
    # Construct from raw edges.

    cl = FacilitationTopology(; A = [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ])
    m = base + cl
    @test m.facilitation_links == [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ]

    # Alternate adjacency input.
    @test m.facilitation_links == get_facilitation_links(
        base + FacilitationTopology(; A = [:b => :c, :c => [:b, :d], :d => :b]),
    )
    @test typeof(cl) === FR

    # Can't specify outside potential links.
    @sysfails(
        base + FacilitationTopology(; A = [
            1 0 0 0
            1 0 0 0
            1 0 0 0
            0 1 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'A' at edge index [1, 1] (true), \
         but the template for 'potential facilitation link' \
         only allows values at the following indices:\n  \
         [(1, 2), (3, 2), (4, 2), (1, 3), (2, 3), (4, 3), (1, 4), (2, 4), (3, 4)]"
    )
    @argfails(FacilitationTopology(; A = [], b = 5), "Unexpected argument: b = 5.")

    #---------------------------------------------------------------------------------------
    # Draw random links instead.
    Random.seed!(12)

    # From a number of links.
    cl = FacilitationTopology(; L = 4, sym = false)

    # Stochastic expansion!
    m = base + cl
    @test m.facilitation_links == [
        0 0 0 0
        0 0 0 0
        0 1 0 1
        0 1 1 0
    ]
    # So, surprisingly:                 /!\
    @test (base + cl).facilitation_links != (base + cl).facilitation_links

    # Or from connectance.
    m = base + FacilitationTopology(; C = 0.5)
    @test m.facilitation_links == [
        0 0 0 1
        0 0 0 1
        0 1 0 1
        0 0 0 0
    ]

    @argfails(
        FacilitationTopology(; n_links = 3, C = 0.5),
        "Cannot specify both connectance and number of links \
         for drawing random facilitation links. \
         Received both 'n_links' argument (3) and 'C' argument (0.5)."
    )
    # Cannot cheat: the above is just a safety guard,
    # but the true, full check happens prior to expansion.
    cl = FacilitationTopology(; conn = 3)
    cl.L = 4
    @sysfails(base + cl, Check(RD), "Both 'C' and 'L' specified on blueprint.")
    cl.C = cl.L = nothing
    @sysfails(base + cl, Check(RD), "Neither 'C' or 'L' specified on blueprint.")
    @sysfails(
        base + FacilitationTopology(; L = 3, symmetry = true),
        Check(RD),
        "Cannot draw L = 3 links symmetrically: pick an even number instead."
    )
    @sysfails(
        base + FacilitationTopology(; L = 11),
        Check(RD),
        "Cannot draw L = 11 facilitation links \
         with these 3 producers and 1 consumer (max: L = 9)."
    )

    # ======================================================================================
    # Layer data.

    # Intensity.
    ci = FacilitationIntensity(5)
    @test ci.eta == 5
    m = base + ci
    @test m.facilitation_layer_intensity == 5
    # Modifiable.
    m.facilitation_layer_intensity = 8
    @test m.facilitation_layer_intensity == 8

    # Functional form.
    cf = FacilitationFunctionalForm((x, dx) -> x - dx)
    m = base + cf
    @test m.facilitation_layer_functional_form(4, 5) == -1
    # Modifiable.
    m.facilitation_layer_functional_form = (x, dx) -> x + dx
    @test m.facilitation_layer_functional_form(4, 5) == 9

    f(x) = "nok"
    @argfails(
        m.facilitation_layer_functional_form = f,
        "Facilitation layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )
    @sysfails(
        base + FacilitationFunctionalForm(f),
        Check(FacilitationFunctionalForm),
        "Facilitation layer functional form signature \
         should be (Float64, Float64) -> Float64. \
         Received instead: f\n\
         with signature:   (Float64, Float64) -> Any[]"
    )

    # ======================================================================================
    # Aggregate behaviour component.

    # (this needs more input for some (legacy?) reason)
    base += BodyMass(1) + MetabolicClass(:all_invertebrates)

    cl = FacilitationLayer(; topology = [
        0 0 0 0
        0 0 1 0
        0 1 0 1
        0 1 0 0
    ], intensity = 5)
    m = base + cl

    # All components brought at once.
    @test m.n_facilitation_links == 4
    @test m.facilitation_layer_intensity == 5
    @test m.facilitation_layer_functional_form(4, -5) == -16

    # From a number of links.
    cl = FacilitationLayer(; A = (L = 4, sym = false), I = 8)

    # Sub-blueprints are all here.
    @test cl.topology.L == 4
    @test cl.topology.symmetry == false
    @test cl.intensity.eta == 8
    @test cl.functional_form.fn(5, -8) == -35

    # And bring them all.
    m = base + cl
    @test m.n_facilitation_links == 4
    @test m.facilitation_layer_intensity == 8
    @test m.facilitation_layer_functional_form(4, -5) == -16

    @sysfails(
        base + FacilitationLayer(),
        Check(FacilitationLayer),
        "missing a required component '$FacilitationTopology': optionally brought."
    )
    @sysfails(
        base + FacilitationLayer(; A = (L = 4, sym = true), F = nothing),
        Check(FacilitationLayer),
        "missing required component '$FacilitationFunctionalForm': optionally brought."
    )

end
