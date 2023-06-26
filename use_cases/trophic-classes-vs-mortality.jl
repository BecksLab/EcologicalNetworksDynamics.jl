import AlgebraOfGraphics: set_aog_theme!
import ColorSchemes: tol_light
import DiffEqCallbacks: CallbackSet, TerminateSteadyState
import Statistics: mean, std

using CairoMakie
using DataFrames
using DifferentialEquations
using EcologicalNetworksDynamics

# Define global community parameters.
S = 50 # Species richness.
C = 0.06 # Trophic connectance.
Z = 50 # Predator-prey bodymass ratio.
i_intra = 0.8 # Intraspecific interference.
n_foodweb = 50 # Number of replicates of trophic networks.
n_d = 6 # Number of tested mortality values.
d0_values = LinRange(0, 5, n_d) # Mortality range.
n_class = length(trophic_classes()) # Plants, intermediate consumers and top predators.
class_matrix = zeros(n_foodweb, n_d, n_class) # Store the diversity in each trophic class.
check_cycle = true # Check that generated food webs do not contain cycle(s).

# Set up simulation parameters.
# For this specific set-up we need to define callbacks manually
# to ensure that the simulation stops when a fixed point is reached,
# and not before.
# To do so, we have lowered the `abstol` and `reltol` arguments of
# `TerminateSteadyState`.
verbose = false # Do not show '@info' messages during simulation run.
tmax = 10_000

# Main simulation loop.
# Each thread writes in its own DataFrame. Merge them at the end of the loop.
dfs = [DataFrame() for _ in 1:n_foodweb] # Fill the vector with empty DataFrames.
Threads.@threads for i in 1:n_foodweb # Parallelize computation when possible.
    df_thread = DataFrame(; # To store simulation data.
        foodweb_id = Int64[],
        d0 = Float64[],
        n_producers = Int64[],
        n_intermediate_consumers = Int64[],
        n_top_predators = Int64[],
    )
    # We first define the food web structure as well as the trophic parameters
    # that are kept constant. We check that there is no cycle so that the trophic levels
    # and thus the trophic classes are well defined.
    foodweb = FoodWeb(nichemodel, S; C, Z, check_cycle)
    # Set intraspecific predator interference.
    functional_response = ClassicResponse(foodweb; c = i_intra)
    B0 = rand(S) # Initial biomass associated with the food web.
    classes = nothing
    # Loop on the mortality intensity that is incremented at each iteration.
    for (j, d0) in enumerate(d0_values)
        # Scale default mortality rates by `d0`.
        d = d0 .* allometric_rate(foodweb, DefaultMortalityParams())
        biorates = BioRates(foodweb; d)
        p = ModelParameters(foodweb; functional_response, biorates)
        callback = CallbackSet(
            ExtinctionCallback(1e-5, p, verbose),
            TerminateSteadyState(1e-8, 1e-6),
        )
        # Prepare simulation boost.
        solution = simulate(p, B0; tmax, callback)
        extinct_sp = keys(get_extinct_species(solution))
        surviving_sp = setdiff(1:richness(foodweb), extinct_sp)
        # Species classes are given by the the dynamics with zero mortality rate.
        d0 == 0 && (classes = trophic_classes(remove_species(foodweb, extinct_sp)))
        # Record the surviving species in each class
        # after running the dynamic with an increased mortality.
        n_per_class = [length(intersect(class, surviving_sp)) for class in classes]
        push!(df_thread, vcat(i, d0, n_per_class))
        @info "foodweb $i, d0 = $d0: done."
    end
    dfs[i] = df_thread
end
@info "All simulations done."
df = reduce(vcat, dfs)

# Process data.
# Group data per food web to compute the relative difference in diversity
# for each trophic class of each food web,
# compared to the reference given by d0 = 0.
relative_difference(x, x_ref) = x_ref == 0 ? 0 : (x_ref - x) / x_ref
groups = groupby(df, :foodweb_id)
for sub_df in groups
    reference_row = findfirst(==(0), sub_df.d0)
    ref_prod = sub_df[reference_row, :n_producers]
    ref_cons = sub_df[reference_row, :n_intermediate_consumers]
    ref_pred = sub_df[reference_row, :n_top_predators]
    transform!(
        sub_df,
        :d0,
        :n_producers => ByRow(x -> relative_difference(x, ref_prod)) => :delta_producers,
        :n_intermediate_consumers =>
            ByRow(x -> relative_difference(x, ref_cons)) => :delta_intermediate_consumers,
        :n_top_predators =>
            ByRow(x -> relative_difference(x, ref_pred)) => :delta_top_predators,
    )
end

# Recombine the DataFrames with the new column corresponding to the class differences.
df = combine(groups, :)
# Group DataFrames per mortality rate (d0), and compute the mean and the confidence
# interval in each trophic class for each mortality value.
ci95(x) = 1.96 * std(x) / sqrt(length(x)) # Confidence interval at 95%.
df_processed = combine(
    groupby(df, :d0),
    :delta_producers => mean,
    :delta_producers => ci95,
    :delta_intermediate_consumers => mean,
    :delta_intermediate_consumers => ci95,
    :delta_top_predators => mean,
    :delta_top_predators => ci95,
)

# Plot relative loss in each trophic class versus the mortality rate intensity.
set_aog_theme!()
fig = Figure()
ax = Axis(fig[2, 1]; xlabel = "Mortality rate, d₀", ylabel = "Relative loss", xticks = 0:5)
curves = []
x = df_processed[:, :d0]
colors = tol_light[1:n_class]
for (class, color) in zip(trophic_classes(), colors)
    col_mean = join(["delta", class, "mean"], "_")
    col_ci = join(["delta", class, "ci95"], "_")
    y = df_processed[:, col_mean]
    ci = df_processed[:, col_ci]
    sl = scatterlines!(x, y; color, markercolor = color)
    errorbars!(x, y, ci; color, whiskerwidth = 5)
    push!(curves, sl)
end
Legend(
    fig[1, 1],
    curves,
    ["producers", "intermediate\nconsumers", "top predators"];
    orientation = :horizontal,
    tellheight = true, # Adjust top subfigure height to legend height.
    tellwidth = false, # Do not adjust bottom subfigure width to legend width.
)

# To save the figure, uncomment and execute the line below.
# save("/tmp/plot.png", fig; resolution = (450, 300), px_per_unit = 3)
