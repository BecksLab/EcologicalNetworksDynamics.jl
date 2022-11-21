@testset "Producer growth rate" begin

    # Set up
    foodweb = FoodWeb([0 0; 0 0]; quiet = true)
    params = ModelParameters(foodweb; biorates = BioRates(foodweb; d = 0))

    sim = simulates(params, [0, 0.5]; verbose = false)
    normal_growth = producer_growth(sim; last = 1, out_type = :all)
    # If biomass equal to 0, growth rate equal to 0
    @test normal_growth.G[normal_growth.s.=="s1"][1][1] ≈ 0.0

    first_growth = producer_growth(sim; last = length(sim.t), out_type = :all)
    # First growth rate should be equal to the logisticgrowth with initial
    # biomass
    params = get_parameters(sim)
    s, r, K = params.network.species, params.biorates.r, params.environment.K

    @test first_growth.G[first_growth.s.=="s2"][1][1] ==
          BEFWM2.logisticgrowth.(0.5, r[s.=="s2"], K[s.=="s2"])[1]
    @test first_growth.G[first_growth.s.=="s2"][1][1] == 0.25

    # Growth rate should converge to 0 as B converges to K
    @test isapprox(
        first_growth.G[first_growth.s.=="s2"][1][length(sim.t)],
        0.0,
        atol = 10^-3,
    )

    # Growth rate computed only for producers
    foodweb = FoodWeb([1 0; 0 0]; quiet = true)
    params = ModelParameters(foodweb)
    sim = simulates(params, [0.5, 0.5]; verbose = true)
    normal_growth = producer_growth(sim; last = 1, out_type = :all)

    @test length(normal_growth.s) == 1

    # Test structure:
    avg_g = producer_growth(sim; last = 20, out_type = :mean)
    sd_g = producer_growth(sim; last = 20, out_type = :std)
    @test length(avg_g.G) == length(sd_g.G) == 1
end


@testset "Total biomass, species persistence, Hill numbers" begin

    # Set up
    foodweb = FoodWeb([0 0; 0 0]; quiet = true)
    params = ModelParameters(foodweb; biorates = BioRates(foodweb; d = 0))

    sim_two_sp = simulates(params, [0.5, 0.5]; verbose = false)
    sim_one_sp = simulates(params, [0, 0.5]; verbose = false)
    sim_zero = simulates(params, [0, 0]; verbose = false)

    # Total biomass should converge to K
    @test isapprox(
        total_biomass(sim_one_sp; last = 1),
        get_parameters(sim_one_sp).environment.K[2],
        rtol = 0.001,
    )

    @test total_biomass(sim_zero; last = 2) ≈ 0.0
    # Species richness is the binary equivalent of total_biomass
    @test foodweb_richness(sim_zero; last = 2) ≈ 0.0
    @test species_persistence(sim_zero; last = 2) ≈ 0.0 # Weird but it is a feature

    @test BEFWM2.species_richness(sim_two_sp[:, end]) ==
          foodweb_richness(sim_two_sp; last = 1) ==
          2
    @test BEFWM2.species_richness(sim_one_sp[:, end]) ==
          foodweb_richness(sim_one_sp; last = 1) ==
          1
    @test BEFWM2.species_richness(sim_zero[:, end]) ==
          foodweb_richness(sim_zero; last = 1) ==
          0

    # Other hill diversity numbers
    ## Shannon
    @test BEFWM2.shannon(sim_two_sp[:, end]) ==
          foodweb_shannon(sim_two_sp; last = 1) ==
          log(2)
    @test BEFWM2.shannon(sim_one_sp[:, end]) == foodweb_shannon(sim_one_sp; last = 1) ≈ 0.0 # 0 entropy if 1 species only
    @test isnan(BEFWM2.shannon(sim_zero[:, end])) ==
          isnan(foodweb_shannon(sim_zero; last = 1)) # Not defined for 0 species

    ## Simpson
    @test BEFWM2.simpson(sim_two_sp[:, end]) ==
          foodweb_simpson(sim_two_sp; last = 1) ==
          1 / sum(2 .^ [1 / 2, 1 / 2])
    @test BEFWM2.simpson(sim_one_sp[:, end]) ==
          foodweb_simpson(sim_one_sp; last = 1) ==
          1 / sum(2 .^ 1) ==
          0.5# 0.5 if 1 species only
    @test isnan(BEFWM2.simpson(sim_zero[:, end])) ==
          isnan(foodweb_simpson(sim_zero; last = 1)) # Not defined for 0 species

    # Community evenness
    @test BEFWM2.pielou(sim_two_sp[:, end]) == foodweb_evenness(sim_two_sp; last = 1) ≈ 1.0 # Maximum equity of species biomass
    @test isnan(BEFWM2.pielou(sim_one_sp[:, end])) ==
          isnan(foodweb_evenness(sim_one_sp; last = 1))# Should be NaN if 1 species
    @test isnan(BEFWM2.pielou(sim_zero[:, end])) ==
          isnan(foodweb_evenness(sim_zero; last = 1))# Should be NaN if 0 species

end
