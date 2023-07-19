@testset "Bioenergetic response component." begin

    Random.seed!(12)

    base = Model(
        Foodweb(:niche; S = 5, C = 0.2),
        BodyMass(1),
        MetabolicClass(:all_invertebrates),
    )

    # Code component blueprint brings all required data components with it.
    ber = BioenergeticResponse()
    @test ber.e.e_herbivorous == 0.45
    @test ber.y.allometry[:i][:a] == 8.0
    @test ber.h == HillExponent(2)

    m = base + ber
    @test m.h == 2
    @test m.y == [0, 0, 0, 8, 8]
    @test m.half_saturation_density == [0, 0, 0, 0.5, 0.5]
    @test m.intraspecific_interference == zeros(5)
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
    ber = BioenergeticResponse(; c = [0, 0, 0, 1, 2])
    @test ber.e.e_herbivorous == 0.45
    @test ber.y.allometry[:i][:a] == 8.0
    @test ber.h == HillExponent(2)
    @test ber.c == IntraspecificInterference([0, 0, 0, 1, 2])

    m = base + ber
    @test m.h == 2
    @test m.y == [0, 0, 0, 8, 8]
    @test m.half_saturation_density == [0, 0, 0, 0.5, 0.5]
    @test m.intraspecific_interference == [0, 0, 0, 1, 2]

    # Cannot bring blueprints if corresponding components are already there.
    @sysfails(
        base + HillExponent(3) + BioenergeticResponse(; h = 2),
        Check(BioenergeticResponse),
        "blueprint also brings '$HillExponent', which is already in the system."
    )

    # In this situation, just stop bringing.
    m = base + HillExponent(3) + BioenergeticResponse(; h = nothing)
    @test m.h == 3

end
