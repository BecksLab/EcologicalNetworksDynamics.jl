using AlgebraOfGraphics
using CairoMakie
using DataFrames
using DifferentialEquations
using DiffEqCallbacks
using EcologicalNetworksDynamics
set_aog_theme!() # Default plot config.

S_pool = 30 # Number of species in the pool, that is, before assembly.
T_values = range(290, 310; length = 10) # Temperature range.
C_competition = 0.1 # Connectance of competition for space links.
C = 0.06 # Connectance of the trophic backbone.
foodweb = Foodweb(:niche; S = S_pool, C = C)
intensity_values = range(0, 100; length = 3)

n = 10
foodweb = Foodweb([0 0 0; 1 0 0; 0 1 0])
t = 315_360_000_000 # From Binzer et al., 2012.
temperature_values = range(263.15, 313.15; length = n)
f0_values = range(0, 5; length = n)
df = DataFrame(; temperature = [], biomass = [], trophic_level = [], f0 = [])
for T in temperature_values, f0 in f0_values
    model = default_model(
        foodweb,
        BodyMass(; Z = 1),
        NontrophicLayers(; facilitation = (; intensity = f0, A = [0 0 0; 1 0 0; 0 0 0])),
        Temperature(T),
    )
    solution = simulate(model, rand(3), t)
    for tl in 1:3
        push!(df, (T, solution[end][tl], string(tl), f0))
    end
end

df_top = df[df.trophic_level.=="3", :]
# Heatmap of surviving species.
fig = Figure();
ax = Axis(fig[1, 1]; xlabel = "Temperature [K]", ylabel = "Facilitation strength")
heatmap!(
    ax,
    Float64.(df_top.temperature),
    Float64.(df_top.f0),
    Float64.(df_top.biomass);
    colormap = :viridis,
)
limits = extrema(df_top.biomass)
Colorbar(fig[1, 2]; label = "Biomass of top predator", colormap = :viridis, limits)
save("temperature-x-nontrophic.png", fig; size = (450, 300), px_per_unit = 3)
