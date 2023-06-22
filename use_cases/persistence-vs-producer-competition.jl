import AlgebraOfGraphics: set_aog_theme!
import ColorSchemes: get, viridis
import Statistics: mean, std

using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

# Define global community parameters.
S = 20 # Species richness.
Z = 100 # Predator-prey bodymass ratio.
K = 1.0 # Producer carrying capacity.
αii = 1.0 # Intraspecific competition among producers.
extinction_threshold = 1e-6 # Set biomass threshold to consider a species extinct.
n_replicates = 100 # Number of food web replicates for each parameter combination.
αij_values = 0.8:0.05:1.2 # Interspecific competition values.
C_values = [0.05, 0.1, 0.2] # Connectance values.
tol_C = 0.01 # Tolerance on connectance when generating foodweb with the nichemodel.
tmax = 2_000 # Simulation length.
verbose = false # Do not show '@info' messages during simulation run.

"""
Standardize total carrying capacity `K` for the number of producers in the `foodweb`
and interspecific competition among producers `αij`.
"""
function standardize_K(foodweb, K, αij)
    n_producer = length(producers(foodweb))
    K * (1 + (αij * (n_producer - 1))) / n_producer
end

# Main simulation loop.
# Each thread writes in its own DataFrame. Merge them at the end of the loop.
dfs = [DataFrame() for _ in 1:length(C_values)] # Fill the vector with empty DataFrames.
Threads.@threads for (i_C, C) in C_values # Parallelize on connctance values.
    df_thread = DataFrame(; C = Float64[], αij = Float64[], persistence = Float64[])
    for i in 1:n_replicates
        foodweb = FoodWeb(nichemodel, S; Z, C, tol_C)
        for αij in αij_values
            producer_competition = ProducerCompetition(foodweb; αii, αij)
            environment = Environment(foodweb; K = standardize_K(foodweb, K, αij))
            params = ModelParameters(foodweb; producer_competition, environment)
            B0 = rand(S) # Initial biomass.
            solution = simulate(params, B0; extinction_threshold, tmax, verbose)
            # Measure species persistence i.e. the number of species that have
            # a biomass above 0 (`threshold`) at the last timestep (`last`).
            persistence = species_persistence(solution; threshold = 0, last = 1)
            push!(df_thread, [C, αij, persistence])
            @info "C = $C, foodweb = $i, αij = $αij: done."
        end
    end
    dfs[i_C] = df_thread
end
@info "All simulations done."
df = reduce(vcat, dfs)

# Compute the mean persistence and the 95% confidence interval (`ci95`)
# for each (C, αij) combination.
groups = groupby(df, [:C, :αij])
df_processed = combine(
    groups,
    :persistence => mean,
    :persistence => (x -> 1.96 * std(x) / sqrt(length(x))) => :ci95,
)

# Plot mean species persistence with its confidence interval
# versus αij for each connectance value.
set_aog_theme!()
fig = Figure()
ax = Axis(
    fig[2, 1];
    xlabel = "Interspecific producer competition, αᵢⱼ",
    ylabel = "Species persistence",
)
curves = []
colors = [get(viridis, val) for val in LinRange(0, 1, length(C_values))]
for (C, color) in zip(C_values, colors)
    df_extract = df_processed[df_processed.C.==C, :]
    x = df_extract.αij
    y = df_extract.persistence_mean
    ci = df_extract.ci95
    sl = scatterlines!(x, y; color = color, markercolor = color)
    errorbars!(x, y, ci; color, whiskerwidth = 5)
    push!(curves, sl)
end
Legend(
    fig[1, 1],
    curves,
    ["C = $C" for C in C_values];
    orientation = :horizontal,
    tellheight = true, # Adjust top subfigure height to legend height.
    tellwidth = false, # Do not adjust bottom subfigure width to legend width.
)
