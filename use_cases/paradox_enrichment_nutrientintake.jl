import AlgebraOfGraphics: set_aog_theme!

using CairoMakie
using DataFrames
using EcologicalNetworksDynamics
using Distributions
using OrdinaryDiffEq

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
S_values = LinRange(0, 70, 20)
tmax = 10_000 # Simulation length.
verbose = false # Do not show '@info' messages during the simulation.
df = DataFrame(;
    S = Float64[],
    B_resource_min = Float64[],
    B_resource_max = Float64[],
    B_consumer_min = Float64[],
    B_consumer_max = Float64[],
)

# Run simulations: compute equilibirum biomass for each carrying capacity.
@info "Start simulations..."
for s in S_values
    for _ in 1:10
        k1 = 0.1 #round(rand(Uniform(0.1, 0.2), 1)[1]; digits = 2)
        k2 = 0.1 #round(rand(Uniform(0.1, 0.2), 1)[1]; digits = 2)
        d = 0.1 #round(rand(Uniform(0.1, 0.4), 1)[1]; digits = 2)
        growthmodel = NutrientIntake(
            foodweb;
            supply = s,
            half_saturation = hcat(k1, k2),
            turnover = d,
        )
        params =
            ModelParameters(foodweb; functional_response, producer_growth = growthmodel)
        callback = ExtinctionCallback(1e-6, params, verbose)
        B0 = 1 .+ 3 * rand(2) # Inital biomass.
        N0 = 1 .+ 3 * rand(2) # Initial nutrient abundances.
        solution = simulate(
            params,
            B0;
            N0,
            tmax,
            verbose,
            alg_hints = [:stiff],
            callback,
            reltol = 1e-5,
        )
        if solution.retcode == ReturnCode.Success
            extrema = biomass_extrema(solution, "10%")
            push!(df, [s, extrema[1].min, extrema[1].max, extrema[2].min, extrema[2].max])
        end
    end
    @info "Simulation for supply S = $s done."
end
@info "Simulations done."

# Plot the orbit diagram with Makie.
df2 = groupby(df, :S)
df2 = combine(
    df2,
    :B_resource_min => mean,
    :B_resource_max => mean,
    :B_consumer_min => mean,
    :B_consumer_max => mean,
)
set_aog_theme!() # AlgebraOfGraphics theme.
c_r = :green # Resource color.
c_c = :purple # Consumer color.
c_v = :grey # Vertical lines color.
fig = Figure()
ax = Axis(fig[2, 1]; xlabel = "Supply, S", ylabel = "Equilibrium biomass")
resource_line =
    scatterlines!(df2.S, df2.B_resource_min_mean; color = c_r, markercolor = c_r)
scatterlines!(df2.S, df2.B_resource_max_mean; color = c_r, markercolor = c_r)
consumer_line =
    scatterlines!(df2.S, df2.B_consumer_min_mean; color = c_c, markercolor = c_c)
scatterlines!(df2.S, df2.B_consumer_max_mean; color = c_c, markercolor = c_c)
Legend(
    fig[1, 1],
    [resource_line, consumer_line],
    ["resource", "consumer"];
    orientation = :horizontal,
    tellheight = true, # Adjust the height of the legend sub-figure.
    tellwidth = false, # Do not adjust width of the orbit diagram.
)
# save("/tmp/plot.png", fig; resolution = (450, 350), px_per_unit = 3)
