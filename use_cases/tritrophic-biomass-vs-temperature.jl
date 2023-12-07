import AlgebraOfGraphics: set_aog_theme!
import ColorSchemes: tol_light
using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

# Temperature gradient from 0 to 40°C, converted to Kelvin, with increments of 1°.
T0 = 273.15 # 0°C in Kelvin.
T40 = T0 + 40 # 40°C in Kelvin.
T_values = values(T0:1:T40)
t = 315_360_000_000 # From Binzer et al., 2012.
trophic_lvl = [1, 2, 3]
df = DataFrame(; T = Float64[], trophic_level = Int64[], Beq = Float64[])

# Run simulations for each temperature across gradient.
@info "Start simulations..."
for T in T_values
    m = default_model(Foodweb([3 => 2, 2 => 1]), BodyMass(1), Temperature(T))
    m.h = 1 # Set hill exponent to 1.
    B0 = m.K[1] / 8 # Inital biomass.
    solution = simulate(m, B0, t)
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
save("/tmp/plot.png", fig; size = (450, 300), px_per_unit = 3)
