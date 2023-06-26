import AlgebraOfGraphics: set_aog_theme!
import ColorSchemes: tol_light

using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

# Create tri-tropic network.
tritrophic = FoodWeb([3 => 2, 2 => 1]) # 3 eats 2, and 2 eats 1.
trophic_lvl = trophic_levels(tritrophic)

# Generate model parameters using Classic functional response.
functional_response = ClassicResponse(tritrophic; h = 1) # Define Holling Type II response.
params = ModelParameters(tritrophic; functional_response)

# Temperature gradient from 0 to 40°C, converted to Kelvin, with increments of 1°.
T0 = 273.15 # 0°C in Kelvin.
T40 = T0 + 40 # 40°C in Kelvin.
T_values = values(T0:1:T40)

# DataFrame to store the simulations outputs.
df = DataFrame(; T = Float64[], trophic_level = Int64[], Beq = Float64[])
# `set_temperature!()` expresses rates in seconds,
# then simulation time is expressed in seconds as well.
# Simulation length and time steps are taken from Binzer et al., 2012.
tmax = 315_360_000_000 # From Binzer et al., 2012.
verbose = false # Do not show '@info' messages during simulation run.
callback = ExtinctionCallback(1e-6, params, verbose) # Remove TerminateSteadyState callback.

# Run simulations for each temperature across gradient.
@info "Start simulations..."
for T in T_values
    set_temperature!(params, T, ExponentialBA()) # Modify parameters with temperature.
    # Simulate biomass dynamics with modified parameters.
    B0 = params.producer_growth.K[1] / 8 # Inital biomass.
    solution = simulate(params, [B0]; tmax, callback)
    Beq_vec = solution[end]
    for (Beq, tlvl) in zip(Beq_vec, trophic_lvl)
        push!(df, [T, tlvl, Beq])
    end
    @info "Simulation for temperature T = $T done."
end
@info "Simulations done."

# Plot equilibrium biomass for each species versus temperature.
set_aog_theme!()
fig = Figure()
ax = Axis(fig[2, 1]; xlabel = "Temperature [°C]", ylabel = "Equilibrium biomass")
curves = []
colors = tol_light[1:3]
markersize_vec = [10, 9, 7]
for (sub_df, color, markersize) in zip(groupby(df, :trophic_level), colors, markersize_vec)
    markercolor = color
    T_celsius = sub_df.T .- T0 # Convert Kelvin to Celsius.
    sl = scatterlines!(T_celsius, sub_df.Beq; color, markercolor, markersize)
    push!(curves, sl)
end
Legend(
    fig[1, 1],
    curves,
    ["producer", "intermediate\nconsumer", "top predator"];
    orientation = :horizontal,
    tellheight = true, # Adjust top subfigure height to legend height.
    tellwidth = false, # Do not adjust bottom subfigure width to legend width.
)

# To save the figure, uncomment and execute the line below.
# save("/tmp/plot.png", fig; resolution = (450, 300), px_per_unit = 3)
