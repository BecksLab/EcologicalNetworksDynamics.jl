@testset "Nutrients nodes component." begin

    n = Nutrients.Nodes(3)
    m = Model(n)
    @test m.n_nutrients == m.nutrients_richness == 3
    @test m.nutrients_names == [:n1, :n2, :n3]

    m = Model(Nutrients.Nodes([:a, :b, :c]))
    @test m.nutrients_index == OrderedDict(:a => 1, :b => 2, :c => 3)

    @sysfails(
        Model(Nutrients.Nodes([:a, :b, :a])),
        Check(Nutrients.Nodes),
        "Nutrients 1 and 3 are both named :a."
    )

end
