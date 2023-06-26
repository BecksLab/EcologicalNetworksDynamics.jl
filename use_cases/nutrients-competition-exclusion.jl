import AlgebraOfGraphics: firasans, set_aog_theme!
using CairoMakie
using EcologicalNetworksDynamics
using Random

foodweb = FoodWeb([0 0; 0 0]) # Two plants competing for nutrients.
half_saturation = [0.3 0.9; 0.9 0.3] # Row <-> plants & column <-> nutrients.
turnover = 0.9
supply = 10
concentration = 1
d = [0.6, 1.2]
r = [1, 2]
tmax = 50
extinction_threshold = 1e-5

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
    Random.seed!(113) # Set seed for reproducibility of initial conditions.
    N0 = 0.1 .+ 3 * rand(n_nutrients)
    B0 = [0.5, 0.5]
    callback = ExtinctionCallback(extinction_threshold, p, true)
    sol = simulate(p, B0; N0, tmax, alg_hints = [:stiff], reltol = 1e-5, callback)
    push!(sol_vec, sol)
end

set_aog_theme!() # AlgebraOfGraphics theme.
fig = Figure()

ax1 = Axis(fig[1, 1]; xlabel = "", ylabel = "", title = "1 nutrient: exclusion")
sol = sol_vec[1]
plant1_line = lines!(sol.t, sol[1, :]; color = :red)
plant2_line = lines!(sol.t, sol[2, :]; color = :green)
nutrient1_line = lines!(sol.t, sol[3, :]; color = :blue, linestyle = :dot)

ax2 = Axis(fig[1, 2]; xlabel = "", ylabel = "", title = "2 nutrients: coexistence")
sol = sol_vec[2]
plant1_line = lines!(sol.t, sol[1, :]; color = :red)
plant2_line = lines!(sol.t, sol[2, :]; color = :green)
nutrient1_line = lines!(sol.t, sol[3, :]; color = :blue, linestyle = :dot)
nutrient2_line = lines!(sol.t, sol[4, :]; color = :black, linestyle = :dot)

font = firasans("Medium") # Label font.
Label(fig[1, 0], "Biomass"; font, rotation = pi / 2, width = 0, tellheight = false)
Label(fig[2, 1:2], "Time"; font, height = 0, tellheight = true)
linkyaxes!(ax1, ax2)
hideydecorations!(ax2; ticks = false)
Legend(
    fig[0, :],
    [plant1_line, plant2_line, nutrient1_line, nutrient2_line],
    ["Plant 1", "Plant 2", "Nutrient 1", "Nutrient 2"];
    orientation = :horizontal,
    tellheight = true, # Adjust the height of the legend sub-figure.
    tellwidth = false, # Do not adjust width of the orbit diagram.
)
save("/tmp/plot.png", fig; resolution = (450, 300), px_per_unit = 3)
