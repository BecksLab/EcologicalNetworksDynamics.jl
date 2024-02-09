# Check the most simple uses of the package.
# Stability desired.

using Random
Random.seed!(12)

#-------------------------------------------------------------------------------------------
@testset "Basic befault pipeline." begin

    fw = Foodweb([0 1 0; 0 0 1; 0 0 0])  # (inline matrix input)
    m = default_model(fw)
    B0 = [0.5, 0.5, 0.5]
    sol = simulate(m, B0)
    @test sol.u[end] ≈ [0.04885048633720308, 0.1890242584230083, 0.22059687801237501]

end

#-------------------------------------------------------------------------------------------
@testset "Basic pipeline à-la-carte." begin

    # Start from empty model.
    m = Model()

    # Add components one by one.
    add!(m, Foodweb([:a => :b, :b => :c])) # (named adjacency input)
    add!(m, BodyMass(1))
    add!(m, MetabolicClass(:all_invertebrates))
    add!(m, BioenergeticResponse(; w = :homogeneous, half_saturation_density = 0.5))
    add!(m, LogisticGrowth(; r = 1, K = 1))
    add!(m, Metabolism(:Miele2019))
    add!(m, Mortality(0))

    # Simulate.
    sol = simulate(m, 0.5) # (all initial values to 0.5)
    @test sol.u[end] ≈ [0.04885048633720308, 0.1890242584230083, 0.22059687801237501]

end

#-------------------------------------------------------------------------------------------
@testset "All-in-constructor style." begin

    m = Model(
        Foodweb([:a => :b, :b => :c]),
        BodyMass(1),
        MetabolicClass(:all_invertebrates),
        BioenergeticResponse(),
        LogisticGrowth(),
        Metabolism(:Miele2019),
        Mortality(0),
    )

    sol = simulate(m, [0.5, 0.5, 0.5])
    @test sol.u[end] ≈ [0.04885048633720308, 0.1890242584230083, 0.22059687801237501]

end

#-------------------------------------------------------------------------------------------
@testset "Infix operator style." begin

    # Construct blueprints independently from each other.
    fw = Foodweb([:a => :b, :b => :c])
    bm = BodyMass(1)
    mc = MetabolicClass(:all_invertebrates)
    be = BioenergeticResponse()
    lg = LogisticGrowth()
    mb = Metabolism(:Miele2019)
    mt = Mortality(0)

    # Expand them all into the global model.
    m = Model() + fw + bm + mc + be + lg + mb + mt
    # (this produces a system copy on every '+')

    sol = simulate(m, 0.5)
    @test sol.u[end] ≈ [0.04885048633720308, 0.1890242584230083, 0.22059687801237501]

end

#-------------------------------------------------------------------------------------------
@testset "Basic non-default functional response." begin

    fw = Foodweb([ # (multiline matrix input)
        0 1 0
        0 0 1
        0 0 0
    ])

    # If provided, the default will not be used.
    m = default_model(fw, ClassicResponse())

    sol = simulate(m, 0.5)
    @test sol.u[end] ≈ [0.2246409590398916, 0.09112832180307448, 0.5444058436109662]

end

#-------------------------------------------------------------------------------------------
@testset "Basic NTI pipeline." begin

    m = default_model(
        Foodweb([1 => 2, 2 => 3]),
        # Add one facilitation interaction randomly.
        FacilitationLayer(; A = (L = 1,)),
    )

    sol = simulate(m, 0.5)
    @test sol.u[end] ≈ [0.24726844778226592, 0.09114742274197872, 0.6904984843155931]

end

#-------------------------------------------------------------------------------------------
@testset "Multiple NTI layers." begin

    m = default_model(
        Foodweb([:a => (:b, :c), :d => (:b, :e), :e => :c]),
        # 2D aliased multiplex API.
        NontrophicLayers(;
            L_facilitation = 1,
            C_refuge = 0.8,
            n_links = (cpt = 2, itf = 2),
        ),
    )

    sol = simulate(m, 0.5)
    @test sol.u[end] ≈ [
        0.29247159105315307
        0.14537825150324735
        0.12875174646007237
        0.0
        4.8215132134864145e-5
    ]

end

#-------------------------------------------------------------------------------------------
@testset "Multiple NTI layers: indirect style." begin

    m = default_model(
        Foodweb([:a => (:b, :c), :d => (:b, :e), :e => :c]),
        ClassicResponse(),
    )

    # Create the layers so they can be worked on first.
    layers = nontrophic_layers(;
        L_facilitation = 1,
        C_refuge = 0.8,
        n_links = (cpt = 2, itf = 2),
    )

    # Access them with convenience aliases.
    m += layers[:facilitation] + layers[:c] + layers["ref"] + layers['i']

    sol = simulate(m, 0.5)
    @test sol.u[end] ≈ [
        0.29247159105315307
        0.14537825150324735
        0.12875174646007237
        0.0
        4.8215132134864145e-5
    ]

end

#-------------------------------------------------------------------------------------------
@testset "Nutrient Intake." begin

    # With nutrients (instead of logistic growth).
    m = default_model(Foodweb([2 => 1, 3 => 2]), NutrientIntake(; concentration = [1 0.5]))
    B0, N0 = rand(3), rand(2)
    sol = simulate(m, B0; N0)
    m._value.producer_growth.concentration
    @test sol.u[end] ≈ [
        0.28423925333678635,
        0.18879238451408806,
        0.1534109945177679,
        9.707009178714864,
        9.853504589357435,
    ]

end
