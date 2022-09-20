# Set up
A = [
    0 0 0 0 0
    1 0 0 1 0
    0 0 0 0 0
    0 0 1 0 1
    0 0 0 0 0
]
input_σ = [0.1, 0.2]
input_θ = [0.2, 0.5, 0.3, 0.4]
foodweb = FoodWeb(A; Z = 10)
producer = BEFWM2.producers(foodweb)
biorates = BioRates(foodweb)

stochasticity = AddStochasticity(
    foodweb,
    addstochasticity = true,
    target = "producers",
    n_species = "all",
    σe = input_σ,
    θ = input_θ,
)

@testset "Correct sampling of stochastic species" begin
    @test stochasticity.stochspecies == producer
    @test stochasticity.stochconsumers == []
    @test stochasticity.stochproducers == stochasticity.stochspecies
end

@testset "Filtering stochastic parameters" begin
    @test stochasticity.μ == biorates.r[stochasticity.stochspecies]
    @test stochasticity.θ == [0.2, 0.5, 0.3]
    @test stochasticity.σe == [0.1, 0.2, 0.1]
    @test stochasticity.σd == zeros(5)
end

# Adding stochasticity to specific species
stochasticity = AddStochasticity(
    foodweb,
    addstochasticity = true,
    target = [2, 3, 4],
    n_species = 3,
    σe = input_σ,
    θ = input_θ,
)

@testset "Correct sampling of stochastic species" begin
    @test stochasticity.stochspecies == [2, 3, 4]
    @test stochasticity.stochconsumers == [2, 4]
    @test stochasticity.stochproducers == [3]
end

@testset "μ from correct BioRates arguments" begin
    @test stochasticity.μ == [biorates.x[2], biorates.r[3], biorates.x[4]]
end
