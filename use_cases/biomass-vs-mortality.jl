using EcologicalNetworksDynamics
using DifferentialEquations
using DiffEqCallbacks
using LaTeXStrings
using Plots
using Statistics

# Define global community parameters.
S = 50 # species richness
C = 0.06 # trophic connectance
Z = 50 # predator-prey bodymass ratio
i_intra = 0.8 # intraspecific interference
n_foodweb = 50 # number of replicates of trophic networks
n_d = 6 # number of tested mortality values
d0_range = LinRange(0, 1, n_d) # mortality range
n_class = length(trophic_classes()) # plants, intermediate consumers and top predators
class_matrix = zeros(n_foodweb, n_d, n_class) # store the diversity in each trophic class

# Main simulation loop.
Threads.@threads for i in 1:n_foodweb # parallelize computation when possible
    # We first define the food web structure as well as the trophic parameters
    # that are kept constant. We check that there is no cycle so that the trophic levels
    # and thus the trophic classes are well defined.
    fw = FoodWeb(nichemodel, S; C, Z, check_cycle = true)
    F = ClassicResponse(fw; c = i_intra) # set intraspecific predator interference
    B0 = rand(S) # initial biomass associated with the food web
    classes = nothing
    # Then we loop on the mortality intensity that we increase at each iteration.
    for (j, d0) in enumerate(d0_range)
        br = BioRates(fw; d = d0 .* allometric_rate(fw, DefaultMortalityParams()))
        p = ModelParameters(fw; functional_response = F, biorates = br)
        # Prepare simulation boost.
        dBdt_expr, data = generate_dbdt(p, :compact)
        dBdt! = eval(dBdt_expr)
        # For this specific set-up we need to define callbacks manually
        # to ensure that the simulation stops when a fixed point is reached,
        # and not before.
        # To do so, we have lowered the `abstol` and `reltol` arguments of
        # `TerminateSteadyState`.
        # Moreover, we have set the `verbose` argument of the `ExtinctionCallback`
        # to remove printed information about species extinctions.
        cb_set =
            CallbackSet(ExtinctionCallback(1e-5, false), TerminateSteadyState(1e-8, 1e-6))
        sol = simulate(
            p,
            B0;
            tmax = 10_000,
            callback = cb_set,
            diff_code_data = (dBdt!, data),
        )
        extinct_sp = keys(get_extinct_species(sol))
        surviving_sp = setdiff(1:richness(fw), extinct_sp)
        # Species classes are given by the the dynamics with zero mortality rate.
        d0 == 0 && (classes = trophic_classes(remove_species(fw, extinct_sp)))
        # Then record the surviving species in each class
        # after running the dynamic with an increased mortality.
        for k in 1:n_class
            class_matrix[i, j, k] = length(intersect(classes[k], surviving_sp))
        end
        println("d0 = $d0 (foodweb $i) done.")
    end
end
println("All simulations done.")

# We compute the relative loss in each trophic class
# for the different mortality intensities
# compared to the classes for a zero mortality rate.
class_variation = zeros(Float64, size(class_matrix))
for i in 1:n_foodweb, j in 1:n_d, k in 1:n_class
    if class_matrix[i, 1, k] == 0
        class_variation[i, j, k] = 0
    else
        class_variation[i, j, k] = 1 - (class_matrix[i, j, k] / class_matrix[i, 1, k])
    end
end
mean_variation = reshape(mean(class_variation; dims = 1), n_d, n_class);
err_variation = reshape(std(class_variation; dims = 1), n_d, n_class) ./ sqrt(n_foodweb)

# Plot relative loss in each trophic class versus the mortality rate intensity.
col = collect(palette(:viridis, n_class))'
plot(d0_range, mean_variation; label = "", color = col, lw = 2)
scatter!(
    d0_range,
    mean_variation;
    labels = ["producers" "intermediate consumers" "top predators"],
    yerr = err_variation,
    markersize = 5,
    markerstrokewidth = 1.2,
    size = (500, 500),
    color = col,
)
xlabel!(L"Mortality rate, $d_0$")
ylabel!(L"Relative loss of trophic class, $\gamma$")
plot!(; size = (MathConstants.φ * 350, 350))
