@testset "Retrieve model from simulation result" begin

    m = default_model(Foodweb([:a => :b]))

    # Simulate.
    sol = simulate(m, 0.5)

    # Change values afterwards.
    @test m.r == [0, 1]
    m.r[2] = 2
    @test m.r[2] == 2

    # Retrieve the original version.
    om = get_model(sol)
    @test om isa Model
    @test om.r == [0, 1]

    # This is also a copy.
    om.r[2] = 3
    @test m.r == [0, 2]
    @test om.r == [0, 3]
    @test get_model(sol).r == [0, 1] # Safe.

end

@testset "Retrieve living/extinct species information." begin

    m = default_model(
        Species([:a, :b, :c, :d]),
        Foodweb([:b => :a, :a => :c, :d => :a]),
        Mortality([0, 1, 0, 1]),
    )
    sim = simulate(m, [1, 0.01, 0.5, 0.1]; tmax = 20, verbose = false)

    t_b = 9.907845041789164
    t_d = 12.462569402727487

    @test extinct_species(sim) == Dict(:b => t_b, :d => t_d)
    @test living_species(sim) == Dict(:a => 1, :c => 3)

end
