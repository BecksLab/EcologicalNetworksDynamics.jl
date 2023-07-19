@testset "Hill exponent component." begin

    m = Model(HillExponent(2))
    @test m.hill_exponent == m.h == 2

    m.h = 3
    @test m.hill_exponent == m.h == 3

    @sysfails(
        Model(HillExponent(-4)),
        Check(HillExponent),
        "Hill exponent needs to be positive. \
         Received: h = -4.0."
    )

end
