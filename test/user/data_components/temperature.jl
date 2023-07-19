@testset "Temperature component." begin

    m = Model(Temperature())
    @test m.temperature == m.T == 293.15

    m = Model(Temperature(200))
    @test m.temperature == m.T == 200.0

    @sysfails(m.T = 5, Property(T), "This property is read-only.")

    @sysfails(
        Model(Temperature(-4)),
        Check(Temperature),
        "Temperature needs to be positive. \
         Received: T = -4.0."
    )

end
