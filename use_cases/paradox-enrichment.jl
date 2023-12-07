import AlgebraOfGraphics: set_aog_theme!
using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

foodweb = Foodweb([2 => 1]) # 2 eats 1.
attack_rate = 1
handling_time = 1
h = 1 # Hill exponent.
t = 1_000 # Simulation duration.
verbose = false # Do not show information messages during simulation.
functional_response = ClassicResponse(; attack_rate, handling_time, h)
extinction_threshold = 1e-6
K_values = LinRange(1, 10, 50)
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
    m = default_model(foodweb, BodyMass(1), CarryingCapacity(K), functional_response)
    B0 = rand(2) # Inital biomass.
    solution = simulate(m, B0, t; extinction_threshold)
    last_points = solution.(0.9*t:1:t)
    last_points = reduce(hcat, last_points) # From vector of vector to matrix.
    Bmin_1, Bmax_1 = extrema(last_points[1, :])
    Bmin_2, Bmax_2 = extrema(last_points[2, :])
    push!(df, [K, Bmin_1, Bmax_1, Bmin_2, Bmax_2])
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
save("/tmp/plot.png", fig; size = (450, 300), px_per_unit = 3)
