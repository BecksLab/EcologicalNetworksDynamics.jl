import AlgebraOfGraphics: firasans, set_aog_theme!
import DiffEqCallbacks: TerminateSteadyState
import DifferentialEquations: CallbackSet
import Statistics: mean, std

using CairoMakie
using DataFrames
using EcologicalNetworksDynamics

# Define global community parameters.
S = 50 # Species richness
Z = 50 # Predator-prey bodymass ratio.
C = 0.06 # Trophic connectance.
i_intra = 0.8 # Intraspecific interference between predators.
C_nti = 0.01 # Non-trophic connectance.
L_nti = round(Integer, S^2 * C_nti) # Number of non-trophic links.
L_nti += isodd(L_nti) # Ensure that number of link is even for symmetric interactions.
n_foodweb = 50 # Replicates of trophic backbones.

# Simulation parameters.
# For this specific set-up we need to define callbacks manually
# to ensure that the simulation stops when a fixed point is reached,
# and not before.
# To do so, we have lowered the `abstol` and `reltol` arguments of
# `TerminateSteadyState`.
tmax = 10_000
verbose = false # Do not show '@info' messages during simulation run.

# Set up non-trophic interactions.
intensity_range_size = 5
range_to(max) = LinRange(0, max, intensity_range_size)
intensity_values_dict = Dict(
    :interference => range_to(4),
    :facilitation => range_to(4),
    :refuge => range_to(5),
    :competition => range_to(0.4),
)
interaction_names = keys(intensity_values_dict)
n_interaction = length(interaction_names)

# Main simulation loop.
# Each thread handle a single food web and writes in its own DataFrame.
# Merge the DataFrames at the end of the loop.
dfs = [DataFrame() for _ in 1:n_foodweb] # Fill the vector with empty DataFrames.
Threads.@threads for i in 1:n_foodweb # Parallelize computation if possible.
    df_thread = DataFrame(;
        foodweb_id = Int64[],
        interaction = Symbol[],
        intensity = Float64[],
        diversity = Int64[],
    )
    # First, create a trophic backbone.
    foodweb = FoodWeb(nichemodel, S; C, Z)
    # Secondly, loop on the different non-trophic interactions to study.
    for interaction in interaction_names
        intensity_values = intensity_values_dict[interaction]
        # Third, increase the non-trophic interaction intensity.
        for intensity in intensity_values
            # Add the given non-trophic interaction to the trophic backbone
            # with the given intensity.
            net = MultiplexNetwork(foodweb; [interaction => (L = L_nti, I = intensity)]...)
            functional_response = ClassicResponse(net; c = i_intra)
            params = ModelParameters(net; functional_response)
            callback = CallbackSet(
                ExtinctionCallback(1e-5, params, verbose),
                TerminateSteadyState(1e-8, 1e-6),
            )
            solution = simulate(params, rand(S); tmax, callback)
            # Save the final diversity at equilibrium.
            push!(df_thread, [i, interaction, intensity, richness(solution[end])])
        end
        @info "Interaction $interaction (foodweb $i) done."
    end
    dfs[i] = df_thread
end
@info "All simulations done."
df = reduce(vcat, dfs)

# Compute the relative diversity different for each network
# compared to the reference network that does not contain non-trophic interactions,
# i.e. non-trophic intensity is null.
groups = groupby(df, [:foodweb_id, :interaction])
for sub_df in groups
    reference_row = findfirst(==(0), sub_df.intensity) # Trophic interactions only.
    S_ref = sub_df[reference_row, :diversity]
    relative_difference(S) = (S - S_ref) / S_ref
    transform!(sub_df, :diversity => ByRow(relative_difference) => :delta_diversity)
end
df = combine(groups, :) # Recombine DataFrames.
# Compute the mean and the confidence interval of diversity variation for each interaction.
ci95(x) = 1.96 * std(x) / sqrt(length(x)) # Confidence interval at 95%.
df_processed = combine(
    groupby(df, [:interaction, :intensity]),
    :delta_diversity => mean,
    :delta_diversity => ci95,
)

# Plot diversity variation versus non-trophic interaction intensity.
set_aog_theme!()
fig = Figure()

# Each non-trophic interaction has its own sub-figure.
groups = groupby(df_processed, :interaction)
indices = Iterators.product(1:2, 1:2) # Iterate over (1, 1) -> (1, 2) -> (2, 1) -> (2, 2).
for (idx, interaction) in zip(indices, interaction_names)
    # Filter rows corresponding to the interaction under study.
    df_interaction = df_processed[df_processed.interaction.==interaction, :]
    ax = Axis(
        fig[idx...];
        title = "$interaction",
        titlefont = firasans("Light"),
        titlegap = 0,
    )
    x = df_interaction.intensity
    y = df_interaction.delta_diversity_mean
    ci = df_interaction.delta_diversity_ci95
    scatterlines!(x, y)
    errorbars!(x, y, ci; whiskerwidth = 5)
end

# Write x and y labels.
font = firasans("Medium") # Label font.
Label(fig[1:2, 0], "Diversity variation"; font, rotation = pi / 2, width = 0)
Label(fig[3, 2:3], "Interaction intensity"; font, height = 0)

# To save the figure, uncomment and execute the line below.
# save("/tmp/plot.png", fig; resolution = (450, 300), px_per_unit = 3)