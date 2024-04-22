# Check post-simulation utils.

using Random
Random.seed!(12)

#-------------------------------------------------------------------------------------------
@testset "Retrieve model from simulation result." begin

    m = default_model(Foodweb([:a => :b, :b => :c]))
    sol = simulate(m, 0.5, 500)

    # Retrieve model from the solution obtained.
    msol = get_model(sol)
    @test msol == m

    # The value we get is a fresh copy of the state at simulation time.
    @test msol !== m # *Not* an alias.

    # Cannot be corrupted afterwards from the original value.
    @test m.K[:c] == 1
    m.K[:c] = 2
    @test m.K[:c] == 2 # Okay to keep working on original value.
    @test msol.K[:c] == 1 # Still true: simulation was done with 1, not 2.

    # Cannot be corrupted afterwards from the retrieved value itself.
    msol.K[:c] = 3
    @test msol.K[:c] == 3 # Okay to work on this one: user owns it.
    @test get_model(sol).K[:c] == 1 # Still true.

end

@testset "Analyze biomass foodweb topology after species removals." begin

    # Simulation not exactly needed for these tests.
    m = Model(Foodweb([:a => [:b, :c], :b => :d, :c => :d, :e => [:c, :f], :g => :h]))
    g = m.trophic_graph

    # Sort to ease testing.
    adjacency(g) = sort(map(species(g)) do sp
        sp => sort(collect(preys(g, sp)))
    end)

    @test adjacency(g) == [
        :a => [:b, :c],
        :b => [:d],
        :c => [:d],
        :d => [],
        :e => [:c, :f],
        :f => [],
        :g => [:h],
        :h => [],
    ]

    # This graph has two disconnected components.
    u, v = disconnected_components(g)
    #! format: off
    @test adjacency(u) == [
        :a => [:b, :c],
        :b => [:d],
        :c => [:d],
        :d => [],
        :e => [:c, :f],
        :f => [],
    ]
    @test adjacency(v) == [
        :g => [:h],
        :h => [],
    ]
    #! format: on

    # But no degenerated species yet.
    @test all(==(Set()), isolated_producers.((g, u, v)))
    @test all(==(Set()), starving_consumers.((g, u, v)))

    # Removing species changes the situation.
    biomass = [name in "cg" ? 0 : 1 for name in "abcdefgh"]
    restrict_to_live!(g, biomass)

    # Now there are three disconnected components.
    u, v, w = disconnected_components(g)
    @test adjacency(u) == [:a => [:b], :b => [:d], :d => []]
    @test adjacency(v) == [:h => []]
    @test adjacency(w) == [:e => [:f], :f => []]

    # A few quirks appear regarding foreseeable equilibrium state.
    @test all(==(Set([:h])), isolated_producers.((g, v)))
    @test all(==(Set()), isolated_producers.((u, w)))
    @test all(==(Set()), starving_consumers.((g, u, v, w)))

    # The more extinct species the more quirks.
    remove_species!(g, :d)
    u, v, w = disconnected_components(g)
    @test adjacency(u) == [:a => [:b], :b => []]
    @test adjacency(v) == [:h => []]
    @test adjacency(w) == [:e => [:f], :f => []]
    @test all(==(Set([:h])), isolated_producers.((g, v)))
    @test all(==(Set([:a, :b])), starving_consumers.((g, u)))
    @test all(==(Set()), isolated_producers.((u, w)))
    @test all(==(Set()), starving_consumers.((v, w)))

    @argfails(
        restrict_to_live!(g, [1]),
        "The given trophic graph originally had 8 species, \
         but the given biomasses vector size is 1."
    )

    # Cannot resurrect species.
    @argfails(
        restrict_to_live!(g, ones(8)),
        "Species :c has been removed from this trophic graph, \
         but it still has a biomass above threshold: 1.0 > 0."
    )

end
