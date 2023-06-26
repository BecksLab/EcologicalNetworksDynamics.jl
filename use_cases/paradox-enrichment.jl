import AlgebraOfGraphics: set_aog_theme!

using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

"""
Compute biomass extrema for each species during the `last` time steps.
"""
function biomass_extrema(solution, last)
    trajectories = extract_last_timesteps(solution; last, quiet = true)
    S = size(trajectories, 1) # Row = species, column = time steps.
    [(min = minimum(trajectories[i, :]), max = maximum(trajectories[i, :])) for i in 1:S]
end

foodweb = FoodWeb([2 => 1]); # 2 eats 1.
functional_response = ClassicResponse(foodweb; aᵣ = 1, hₜ = 1, h = 1);
K_values = LinRange(1, 10, 50)
tmax = 1_000 # Simulation length.
verbose = false # Do not show '@info' messages during the simulation.
df = DataFrame(;
    K = Float64[],
    B_resource_min = Float64[],
    B_resource_max = Float64[],
    B_consumer_min = Float64[],
    B_consumer_max = Float64[],
)

# Run simulations: compute equilibirum biomass for each carrying capacity.
@info "Start simulations..."
for K in K_values
    producer_growth = LogisticGrowth(foodweb; K)
    params = ModelParameters(foodweb; functional_response, producer_growth)
    B0 = rand(2) # Inital biomass.
    solution = simulate(params, B0; tmax, verbose)
    extrema = biomass_extrema(solution, "10%")
    push!(df, [K, extrema[1].min, extrema[1].max, extrema[2].min, extrema[2].max])
    @info "Simulation for carrying capacity K = $K done."
end
@info "Simulations done."

# Plot the orbit diagram with Makie.
set_aog_theme!() # AlgebraOfGraphics theme.
c_r = :green # Resource color.
c_c = :purple # Consumer color.
c_v = :grey # Vertical lines color.
fig = Figure()
ax = Axis(fig[2, 1]; xlabel = "Carrying capacity, K", ylabel = "Equilibrium biomass")
resource_line = scatterlines!(df.K, df.B_resource_min; color = c_r, markercolor = c_r)
scatterlines!(df.K, df.B_resource_max; color = c_r, markercolor = c_r)
consumer_line = scatterlines!(df.K, df.B_consumer_min; color = c_c, markercolor = c_c)
scatterlines!(df.K, df.B_consumer_max; color = c_c, markercolor = c_c)
K0 = 2.3
v_line1 = vlines!(ax, [K0]; color = c_v)
v_line2 = vlines!(ax, [1 + 2 * K0]; color = c_v, linestyle = :dashdot)
Legend(
    fig[1, 1],
    [resource_line, consumer_line, v_line1, v_line2],
    ["resource", "consumer", "K₀", "1+2K₀"];
    orientation = :horizontal,
    tellheight = true, # Adjust the height of the legend sub-figure.
    tellwidth = false, # Do not adjust width of the orbit diagram.
)

# To save the figure, uncomment and execute the line below.
# save("/tmp/plot.png", fig; resolution = (450, 300), px_per_unit = 3)
