@testset "Classic response component." begin

    Random.seed!(12)

    base = Model(Foodweb(:niche; S = 5, C = 0.2), MetabolicClass(:all_invertebrates))

    # Code component blueprint brings all required data components with it..
    clr = ClassicResponse()
    @test isnothing(clr.M) # .. except for the body mass.
    @test clr.w == ConsumersPreferences(:homogeneous)
    @test clr.h == HillExponent(2)
    @test clr.handling_time.h_t == :Miele2019

    # The body mass is typically brought another way.
    bm = BodyMass(1) # (use constant mass to ease later tests)

    m = base + bm + clr
    @test m.h == 2
    @test m.M == ones(5)
    @test m.intraspecific_interference == zeros(5)
    @test m.attack_rate == 50 * m.A
    @test m.handling_time == 0.3 * m.A
    q = 1 / 4
    @test m.w == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        1 0 0 0 0
        0 q q q q
    ]
    a, b = 0.45, 0.85
    @test m.e == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        a 0 0 0 0
        0 a a b b
    ]

    # Customize sub-blueprints:
    clr = ClassicResponse(; M = (; Z = 1.5))
    @test clr.M.Z == 1.5
    @test clr.w == ConsumersPreferences(:homogeneous)
    @test clr.h == HillExponent(2)
    @test clr.handling_time == HandlingTime(:Miele2019)

    m = base + clr
    @test m.h == 2
    @test m.M ≈ [1, 1, 1, 1.5, 1.275424500625791]
    @test m.intraspecific_interference == zeros(5)
    @test round.(m.attack_rate) ≈ [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        60 0 0 0 0
        0 56 56 59 58
    ]
    @test round.(100 * m.handling_time) ≈ [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        25 0 0 0 0
        0 27 27 20 23
    ]
    q = 1 / 4
    @test m.w == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        1 0 0 0 0
        0 q q q q
    ]
    a, b = 0.45, 0.85
    @test m.e == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        a 0 0 0 0
        0 a a b b
    ]

    # Cannot bring blueprints if corresponding components are already there.
    @sysfails(
        base + BodyMass(3) + ClassicResponse(; M = 4),
        Check(ClassicResponse),
        "blueprint also brings '$BodyMass', which is already in the system."
    )

    # In this situation, just stop bringing.
    m = base + BodyMass(3) + ClassicResponse(; M = nothing)
    @test m.M == [3, 3, 3, 3, 3]

end
