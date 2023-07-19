@testset "Linear response component." begin

    Random.seed!(12)

    base = Model(Foodweb(:niche; S = 5, C = 0.2))

    # Code component blueprint brings all required data components with it.
    lr = LinearResponse()
    @test lr.alpha == ConsumptionRate(1)
    @test lr.w == ConsumersPreferences(:homogeneous)

    m = base + lr
    @test m.alpha == [0, 0, 0, 1, 1]
    q = 1 / 4
    @test m.w == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        1 0 0 0 0
        0 q q q q
    ]

    # Customize sub-blueprints:
    lr = LinearResponse(; alpha = [0, 0, 0, 1, 2])
    @test lr.alpha == ConsumptionRate([0, 0, 0, 1, 2])
    @test lr.w == ConsumersPreferences(:homogeneous)

    m = base + lr
    @test m.alpha == [0, 0, 0, 1, 2]
    q = 1 / 4
    @test m.w == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        1 0 0 0 0
        0 q q q q
    ]

    # Cannot bring blueprints if corresponding components are already there.
    @sysfails(
        base + ConsumersPreferences(:homogeneous) + LinearResponse(; w = :homogeneous),
        Check(LinearResponse),
        "blueprint also brings '$ConsumersPreferences', which is already in the system."
    )

    # In this situation, just stop bringing.
    m = base + ConsumersPreferences(5 .* m.A) + LinearResponse(; w = nothing)
    @test m.w == [
        0 0 0 0 0
        0 0 0 0 0
        0 0 0 0 0
        5 0 0 0 0
        0 5 5 5 5
    ]

end
