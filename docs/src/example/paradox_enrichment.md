# Paradox of enrichment

The *paradox of enrichment* is a counter-intuitive phenomenon discovered by
[Micheal Rosenzweig in 1961](https://www.science.org/doi/10.1126/science.171.3969.385).
In a simple 2-species system with one consumer feeding on a resource,
the paradox states that you may destabilize, and eventually eradicate,
the consumer population by enriching the system in resources.
This result is quite surprising as naively
one would expect that increasing the resource input would benefit to the consumers.

In the following we present in length this paradox
and check that our simulations fit with analytical predictions.

## System definition

We consider a 2-species system with one resource (``R``) and one consumer (``C``).

```@example econetd
using EcologicalNetworksDynamics
foodweb = FoodWeb([0 0; 1 0]); # 2 eats 1
```

For the paradox of enrichment to appear,
we need to consider a non-linear functional response.
Here we choose the [`ClassicResponse`](@ref)
with a handling time (`hₜ`), an attack rate (`aᵣ`), and a hill exponent (`h`) equal to one
to simplify analytical derivations.

```@example econetd
functional_response = ClassicResponse(foodweb; aᵣ = 1, hₜ = 1, h = 1);
```

Then, the system dynamics are governed by the following set of ODEs:

```math
\begin{aligned}
\frac{dR}{dt} &= rR(1 - \frac{R}{K}) - C \frac{1}{1 + R} \\
\frac{dC}{dt} &= e C \frac{1}{1 + R} - x C
\end{aligned}
```

with:

  - ``r`` the intrinsic growth of the resource
  - ``K`` the carrying capacity of the resource
  - ``e`` the assimilation efficiency of the predator
  - ``x`` the metabolic demand of the predator

## Stability analysis

The system has three equilibria:

 1. ``(R_1 = 0, C_1 = 0)`` the trivial equilibria were both species are extinct
 2. ``(R_2 = K, C_2 = 0)`` the consumer is extinct and the resource is at its carrying capacity
 3. ``(R_3 = \frac{\frac{x}{e}}{1 - \frac{x}{e}}, C_3 = r (1 + R_3) (1 - \frac{R_3}{K}))``
    both species can coexist

!!! note
    
    Surprisingly, for the third equilibrium the resource biomass does not depend at all on
    its carrying capacity (``K``) or its intrinsic growth rate (``r``),
    but the consumer biomass does.

To go further we can compute the Jacobian of our system
to characterize the stability of the equilibria points.
Specifically, we want to find how the stability of the equilibria
evolves with the resource carrying capacity (``K``).

The Jacobian of the system is:

```math
J(R, C) =
\begin{pmatrix}
r(1-\frac{2R}{K}) - \frac{C}{(1+R)^2} & - \frac{R}{1+R} \\
\frac{eC}{(1+R)^2} & -x + \frac{eR}{1+R}
\end{pmatrix}
```

For the trivial equilibrium:

```math
J(R_1, C_1) =
\begin{pmatrix}
r  & 0 \\
0 & -x
\end{pmatrix}
```

The first equilibrium is a saddle point as
the Jacobian has one positive and one negative eigenvalue.
Thus, as soon as there is a small amount of resource,
the resource population will increase until it reaches its carrying capacity.

That state corresponds to the second equilibrium whose the Jacobian is:

```math
J(R_2, C_2) =
\begin{pmatrix}
-r  & 0 \\
0 & -x + \frac{eK}{1 + K}
\end{pmatrix}
```

This equilibrium is stable if ``K \leq K_0 = \frac{\frac{x}{e}}{1 - \frac{x}{e}}``.
In other words, when the carrying capacity becomes large enough
the consumer can coexist with the resource,
and ``K_0`` is the minimal capacity needed for the consumer to persist.

!!! note
    
    ``K_0`` is positive if and only if ``e \geq x``
    which is the second condition for the consumer to survive.
    Its assimilation of the resource has to be high enough to fulfill its metabolic demand.

Formally, above ``K_0`` the system switches to the third equilibrium whose Jacobian is:

```math
J(R_3, C_3) =
\begin{pmatrix}
r \frac{x}{e} (1 - (\frac{1 + 2 R_3 }{K})) & - \frac{x}{e} \\
C_3 e (1 - \frac{x}{e}))^2 & 0
\end{pmatrix}
```

This equilibrium is stable if both eigenvalues of the Jacobian have a negative real part,
i.e. that the sum of eigenvalues is negative (``Tr(J) \leq 0``)
and the product of eigenvalues is positive (``\Delta(J) \geq 0``).

Eventually, we find that both species can coexist if
``K \leq 1 + 2K_0``.
Here appears the *paradox of enrichment*:
when we increase the resource carrying capacity too much (above ``1 + 2K_0``)
the system is destabilized and starts to oscillate.
Moreover, the amplitude of the oscillations increases with the carrying capacity,
and eventually the species collapse.

## Summary: orbit diagram

The system behavior can be summarized in a single plot, an *orbit diagram*.
The orbit diagram represents the evolution of system (stable) equilibrium
depending on the carrying capacity.
On this orbit diagram, as we expect to obtain limit cycles (for large `K`),
we will only record the biomass extrema during the cycle.

```@example econetd
"""
    biomass_extrema(solution, last)

Compute biomass extrema for each species during the `last` time steps.
"""
function biomass_extrema(solution, last)
    trajectories = extract_last_timesteps(solution; last, quiet = true)
    S = size(trajectories, 1) # Row = species, column = time steps.
    [(min = minimum(trajectories[i, :]), max = maximum(trajectories[i, :])) for i in 1:S]
end
```

All ingredients are ready, we can now mix them together to produce the orbit diagram.

```@example econetd
using AlgebraOfGraphics, CairoMakie, DataFrames
ENV["GKSwstype"] = "100" # don't open a plot window while building the documentation # hide

K_values = LinRange(1, 10, 50)
tmax = 1_000 # Simulation length.
verbose = false # Do not show '@info' messages during the simulation.
df = DataFrame(;
    K = Float64[],
    B_resource_min = Float64[],
    B_resource_max = Float64[],
    B_consumer_min = Float64[],
    B_consumer_max = Float64[],
)

# Run simulations: for each carrying capacity we compute the equilibrium biomass.
for K in K_values
    producer_growth = LogisticGrowth(foodweb; K)
    params = ModelParameters(foodweb; functional_response, producer_growth)
    B0 = rand(2) # Inital biomass.
    solution = simulate(params, B0; tmax, verbose)
    extrema = biomass_extrema(solution, "10%")
    push!(df, [K, extrema[1].min, extrema[1].max, extrema[2].min, extrema[2].max])
end

# Plot the orbit diagram with Makie.
set_aog_theme!() # AlgebraOfGraphics theme.
c_r = :green # Resource color.
c_c = :purple # Consumer color.
c_v = :grey # Vertical lines color.
fig = Figure()
ax = Axis(fig[2, 1]; xlabel = "Carrying capacity, K", ylabel = "Equilibrium biomass")
resource_line = scatterlines!(df.K, df.B_resource_min; color = c_r, markercolor = c_r)
scatterlines!(df.K, df.B_resource_max; color = c_r, markercolor = c_r)
consumer_line = scatterlines!(df.K, df.B_consumer_min; color = c_c, markercolor = c_c)
scatterlines!(df.K, df.B_consumer_max; color = c_c, markercolor = c_c)
K0 = 2.3
v_line1 = vlines!(ax, [K0]; color = c_v)
v_line2 = vlines!(ax, [1 + 2 * K0]; color = c_v, linestyle = :dashdot)
Legend(
    fig[1, 1],
    [resource_line, consumer_line, v_line1, v_line2],
    ["resource", "consumer", "K₀", "1+2K₀"];
    orientation = :horizontal,
    tellheight = true, # Adjust the height of the legend sub-figure.
    tellwidth = false, # Do not adjust the width of the orbit diagram.
)
save("enrichment_orbit-diagram.png", fig; px_per_unit = 3, resolution = (450, 350)); # hide
nothing; # hide
```

![](enrichment_orbit-diagram.png)

As described above we observe three parts in this plot.
First, if ``K \leq K_0`` only the resource survives
and has a biomass equal to its carrying capacity.
Secondly, if ``K_0 \leq K \leq 1 + 2 K_0`` both species can coexist:
the resource has a constant biomass equal to ``K_0``,
while the consumer biomass increases with the carrying capacity.
Thirdly, if ``K \geq 1 + 2 K_0`` then the system is destabilized and starts to oscillate
resulting eventually in the extinction of the species.
