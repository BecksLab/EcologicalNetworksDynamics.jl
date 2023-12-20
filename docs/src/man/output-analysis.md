# Analyse the Simulated Dynamics

Once the dynamics of the community have been simulated, we can analyse the results to better understand the behaviour of the community.
To do so, we provide a few functions to compute various properties of the community dynamics.

Let's first simulate the dynamics of a species-rich community with the niche model:

```@example econetd
using EcologicalNetworksDynamics, Plots
ENV["GKSwstype"] = "100" # See https://documenter.juliadocs.org/stable/man/syntax/ # hide

S = 20 # Number of species.
C = 0.1 # Connectance.
foodweb = Foodweb(:niche; S, C)
m = default_model(foodweb)
B0 = rand(S) # Vector of initial biomasses.
t = 100 # Simulation time.
sol = simulate(m, B0, t)
```

When running the dynamics of a rich initial pool of species, we generally observe the extinction of some species.
You can access the number of surviving species at the end of the simulation with:

```@example econetd
richness(sol[end]) # Number of surviving species at the end of the simulation.
```

You can also get the trajectory of the species richness through time with:

```@example econetd
richness(sol) # Richness at each time step.
```

Similarly, you can compute the persistence, that is the proportion of species that are present at each time step:

```@example econetd
persistence(sol) # Equivalent to: richness(sol) ./ S
```

Or the total biomass of the community:

```@example econetd
total_biomass(sol)
```

Or the shannon diversity index:

```@example econetd
shannon_diversity(sol)
```

For example, you can plot how a few of these properties evolve through time:

```@example econetd
time = sol.t
plot(time, total_biomass(sol); xlabel = "Richness", ylabel = "Observable", label = "Total biomass")
plot!(time, richness(sol); label = "Richness")
plot!(time, shannon_diversity(sol); label = "Shannon diversity")
savefig("output-analysis.png"); nothing # hide
```

![Figure of the simulation](output-analysis.png)
