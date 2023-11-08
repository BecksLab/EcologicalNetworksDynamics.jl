@testset "Extracting simulation tail." begin

    # Set up so the middle species gets extinct.
    m = default_model(
        Species([:a, :b, :c]),
        Foodweb([:b => :a, :a => :c]),
        Mortality([0, 1, 0]),
    )
    sim = simulate(m, [1, 0.01, 0.5]; tmax = 20)
    @test extinct_species(sim) == Dict(:b => 13.231605065619236)

    # Round result (these are *not* numerical tests) and change defaults for testing.
    rtail(args...; warn_late_extinctions = false, warn_empty_tail = false, kwargs...) =
        round.(
            tail(sim, args...; warn_late_extinctions, warn_empty_tail, kwargs...);
            digits = 6,
        )

    # ======================================================================================
    # Check steps extraction.

    # Extract last step.
    @test rtail() == rtail(1) == [
        0.219431
        0.0
        0.18907
    ][:, :]

    # Extract more steps.
    #! format: off
    @test rtail(2) == [
        0.21941  0.219431
        0.0      0.0
        0.188969 0.18907
    ]

    @test rtail(3) == [
        0.21992  0.21941  0.219431
        0.0      0.0      0.0
        0.188195 0.188969 0.18907
    ]

    # With percentages.
    @test rtail("20.5%") == [
        0.222185 0.222185 0.221403 0.21992  0.21941  0.219431
        5.0e-6   0.0      0.0      0.0      0.0      0.0
        0.189273 0.189273 0.187684 0.188195 0.188969 0.18907
    ]
    #! format: on

    # Extracting empty array is okay.
    empty = zeros(Float64, (3, 0))
    @test rtail(0) == empty
    @test rtail("0%") == empty
    @test rtail("1%") == empty

    #---------------------------------------------------------------------------------------
    # Warnings.

    @test_warn("Solution tail of size 0 is an empty table.", tail(sim, 0))

    @test_warn(
        "1.0% of 28 timesteps correspond to 0 output lines: \
         the solution tail is an empty table.",
        tail(sim, "1%"),
    )

    @test_warn(
        "Species 2 (:b) went extinct at time 13.231605065619236, \
         during the extracted simulation tail.",
        tail(sim, "50%"),
    )
    # Warn on the exact same step.
    @test_warn(
        "Species 2 (:b) went extinct at time 13.231605065619236, \
         during the extracted simulation tail.",
        tail(sim, 6),
    )
    #  @test_nowarn tail(sim, 5) # BROKEN because of extinction timestep duplication.
    @test_nowarn tail(sim, 4)

    #---------------------------------------------------------------------------------------
    # Invalid inputs

    @argfails(
        rtail("15%5"),
        "The `last` argument, when given as a string, should end with '%'."
    )

    for i in ["100.1%", "-0.1%"]
        @argfails(
            rtail(i),
            "Cannot extract $i of the solution's timesteps: \
             0% <= `last` <= 100% must hold.",
        )
    end

    @argfails(
        rtail(100),
        "Cannot extract 100 timesteps from a trajectory solution with only 28 timesteps. \
         Consider decreasing the `last` argument value \
         and/or specifying it as a percentage instead (e.g. `\"10%\"`)."
    )

    @argfails(
        rtail(-10),
        "Cannot extract '-10' timesteps. `last` should be a positive integer."
    )

    @argfails(
        rtail(4.5),
        "Invalid `last` specification: '4.5::Float64'. Did you mean \"4.5%\"::String?"
    )

    @argfails(
        rtail([]),
        "Invalid `last` specification. \
         Expected positive integer or percentage string. \
         Got instead: 'Any[]::Vector{Any}'."
    )

    # ======================================================================================
    # Check species extraction.

    # Input flexibility.
    for species in (1, :a, "a", 'a', [1], [:a], ["a"], ['a'])
        @test rtail(3; species) == [0.21992 0.21941 0.219431]
    end

    # Extract several species
    @test rtail(3; species = [:a, :b]) ==
          rtail(3; species = [1, 2]) ==
          [
              0.21992 0.21941 0.219431
              0.0 0.0 0.0
          ]

    # Respect required ordering.
    @test rtail(3; species = [:b, :a]) ==
          rtail(3; species = [2, 1]) ==
          [
              0.0 0.0 0.0
              0.21992 0.21941 0.219431
          ]

    @test rtail(3; species = [:b, :c, :a]) ==
          rtail(3; species = [2, 3, 1]) ==
          [
              0.0 0.0 0.0
              0.188195 0.188969 0.18907
              0.21992 0.21941 0.219431
          ]

    #---------------------------------------------------------------------------------------
    # Invalid input.

    @argfails(rtail(; species = 'x'), "Invalid species name: 'x'. Expected :a, :b or :c.")
    @argfails(rtail(; species = [:x]), "Invalid species name: :x. Expected :a, :b or :c.")
    @argfails(rtail(; species = 4), "Invalid species index when there are 3 species: 4.")
    @argfails(rtail(; species = [4]), "Invalid species index when there are 3 species: 4.")
    @argfails(rtail(; species = [0]), "Invalid species index when there are 3 species: 0.")

end
