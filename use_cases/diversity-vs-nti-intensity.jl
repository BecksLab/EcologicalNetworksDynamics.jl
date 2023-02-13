using DiffEqCallbacks
using DifferentialEquations
using EcologicalNetworksDynamics
using LaTeXStrings
using Plots
using Statistics

# Define global community parameters.
S = 50 # species richness
Z = 50 # predator-prey bodymass ratio
C = 0.06 # trophic connectance
i_intra = 0.8 # intraspecific competition
C_nti = 0.01 # non-trophic connectance
L_nti = round(Integer, S^2 * C_nti) # number of non-trophic links
L_nti += isodd(L_nti) # ensure that number of link is even for symmetric interactions
n_foodweb = 10 # replicates of trophic backbones

# Set up non-trophic interactions.
intensity_range_size = 5
range_to(max) = LinRange(0, max, intensity_range_size)
intensity_dict = Dict( # intensity range for each non-trophic interaction
    :interference => range_to(4),
    :facilitation => range_to(4),
    :refuge => range_to(5),
    :competition => range_to(0.4),
)
interaction_names = keys(intensity_dict)
n_interaction = length(interaction_names)
diversity = zeros(n_interaction, intensity_range_size, n_foodweb) # store final diversity

# Main simulation loop.
# First we create a trophic backbone.
Threads.@threads for i in 1:n_foodweb # parallelize if possible
    foodweb = FoodWeb(nichemodel, S; C, Z)
    # Secondly we loop on the different non-trophic interactions we want to look at.
    for (j, interaction) in enumerate(interaction_names)
        intensity_range = intensity_dict[interaction]
        # Third, we increase the non-trophic interaction intensity.
        for (k, intensity) in enumerate(intensity_range)
            # We add the given non-trophic interaction to the trophic backbone
            # with the given intensity.
            net = MultiplexNetwork(foodweb; [interaction => (L = L_nti, I = intensity)]...)
            F = ClassicResponse(net; c = i_intra)
            p = ModelParameters(net; functional_response = F)
            # For this specific set-up we need to define callbacks manually
            # to ensure that the simulation stops when a fixed point is reached,
            # and not before.
            # To do so, we have lowered the `abstol` and `reltol` arguments of
            # `TerminateSteadyState`.
            # Moreover, we have set the `verbose` argument of the `ExtinctionCallback`
            # to remove printed information about species extinctions.
            cb_set = CallbackSet(
                ExtinctionCallback(1e-5, false),
                TerminateSteadyState(1e-8, 1e-6),
            )
            sol = simulate(p, rand(S); tmax = 10_000, callback = cb_set, verbose = false)
            # We save the final diversity at equilibrium.
            diversity[j, k, i] = species_richness(sol[end])
        end
        println("Interaction $interaction (foodweb $i) done.")
    end
end
println("All simulations done.")

# Compute variation in diversity between trophic only and
# trophic with non-trophic interactions
# for each non-trophic interaction types and for each intensity.
variation = zeros(size(diversity))
for i in 1:n_interaction, j in 1:intensity_range_size, k in 1:n_foodweb
    variation[i, j, k] = (diversity[i, j, k] - diversity[i, 1, k]) / S
end
mean_variation = mean(variation; dims = 3)
err_variation = std(variation; dims = 3) ./ sqrt(n_foodweb)

# Plot relative variation in diversity due to the non-trophic interaction
# versus the non-trophic interaction intensity.
plot_vec = []
for (i, interaction) in enumerate(interaction_names)
    intensity_range = intensity_dict[interaction]
    p = scatter(
        intensity_range,
        mean_variation[i, :];
        yerr = err_variation[i, :],
        color = :black,
        label = "",
    )
    interaction = String(interaction)
    interaction, i0 = uppercasefirst(interaction), first(interaction) * "_0"
    xlabel!(L"%$interaction intensity, $%$i0$")
    ylabel!(L"Diversity variation, $\Delta S$")
    push!(plot_vec, p)
end
plot(plot_vec...)
