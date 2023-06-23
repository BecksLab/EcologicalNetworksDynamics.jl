import AlgebraOfGraphics: set_aog_theme!
using CairoMakie
using EcologicalNetworksDynamics
using Random

foodweb = FoodWeb([0 0; 0 0]) # Two plants competing for nutrients.
half_saturation = [0.3 0.9; 0.9 0.3] # Row <-> plants & column <-> nutrients.
turnover = 0.9
supply = 10
concentration = 1
d = [0.25, 0.5]
r = [1, 2]
tmax = 10_000

sol_vec = []
for n_nutrients in 1:2
    producer_growth = NutrientIntake(
        foodweb;
        n_nutrients,
        supply,
        half_saturation = half_saturation[:, 1:n_nutrients],
        turnover,
        concentration,
    )
    biorates = BioRates(foodweb; d, r)
    p = ModelParameters(foodweb; producer_growth, biorates)
    Random.seed!(123) # Set seed for reproducibility of initial conditions.
    N0 = 1 .+ 3 * rand(n_nutrients)
    B0 = [0.5, 0.5]
    sol = simulate(p, B0; N0, tmax)
    push!(sol_vec, sol)
end

set_aog_theme!() # AlgebraOfGraphics theme.
fig = Figure()

ax = Axis(fig[1, 1]; xlabel = "Time", ylabel = "Biomass", title = "1 nutrient: exclusion")
sol = sol_vec[1]
plant1_line = scatterlines!(sol.t, sol[1, :]; color = :red, markercolor = :red)
plant2_line = scatterlines!(sol.t, sol[2, :]; color = :green, markercolor = :green)


ax = Axis(fig[1, 1]; xlabel = "Time", ylabel = "Biomass", title = "1 nutrient: exclusion")
sol = sol_vec[2]
plant1_line = scatterlines!(sol.t, sol[1, :]; color = :red, markercolor = :red)
plant2_line = scatterlines!(sol.t, sol[2, :]; color = :green, markercolor = :green)

Legend(
    fig[0, 1],
    [plant1_line, plant2_line],
    ["Plant 1", "Plant 2"];
    orientation = :horizontal,
    tellheight = true, # Adjust the height of the legend sub-figure.
    tellwidth = false, # Do not adjust width of the orbit diagram.
)
save("/tmp/plot.png", fig; resolution = (450, 350), px_per_unit = 3)
