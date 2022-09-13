# Paradox of enrichment

```@setup befwm2
using BEFWM2
```

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

```@example befwm2
foodweb = FoodWeb([0 0; 1 0]); # 2 eats 1
```

For the paradox of enrichment to appear,
we need to consider a non-linear functional response.
Here we choose the [`ClassicResponse`](@ref)
with a handling time (`hₜ`), an attack rate (`aᵣ`), and a hill exponent (`h`) equal to one
to simplify analytical derivations.

```@example befwm2
response = ClassicResponse(foodweb; aᵣ = 1, hₜ = 1, h = 1);
```

Then, the system dynamic is governed by the following set of ODEs:

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

This equilibrium is stable if ``K \leq K_c = \frac{\frac{x}{e}}{1 - \frac{x}{e}}``.
In other words, when the carrying capacity becomes large enough
the consumer can coexist with resource,
and ``K_c`` is the minimal capacity needed to maintain the consumer alive.

!!! note
    
    ``K_c`` is positive if and only if ``e \geq x``
    which is the second condition for the consumer to survive.
    Its assimilation of the resource has to be high enough to fulfill its metabolic demand.

Formally, above ``K_c`` the system switch to the third equilibrium whose Jacobian is:

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
``K \leq 1 + 2K_c``.
Here appears the *paradox of enrichment*:
when we increase the resource carrying capacity too much (above ``1 + 2K_c``)
the system is destabilized and start to oscillate.
Moreover, the amplitude of the oscillations increases with the carrying capacity,
and eventually the species collapse.

## Summary: orbit diagram

All the system behavior can be summarized in one plot, that we call an *orbit diagram*.
The orbit diagram represent the evolution of system (stable) equilibrium
depending on the carrying capacity.

```@example befwm2
using Plots # hide
ENV["GKSwstype"] = "100" # don't open a plot window while building the documentation # hide

# Setup
K_list = [1 + 0.1 * i for i in 1:46]
append!(K_list, [5.6 + i * 0.01 for i in 1:440])
R_list = [] # resource final biomass
C_list = [] # consumer final biomass

# Run simulations
for K in K_list
    e = Environment(foodweb; K = K)
    p = ModelParameters(foodweb; functional_response = response, environment = e)
    out = simulate(p, [1, 1]; verbose = false)
    append!(R_list, out.u[end][1])
    append!(C_list, out.u[end][2])
end

# Plot orbit diagram
plot(
    K_list,
    R_list;
    label = "resource",
    xlabel = "K",
    ylabel = "B",
    seriestype = :scatter,
    title = "Orbit diagram",
)
plot!(K_list, C_list; label = "consumer", seriestype = :scatter, legend = :topleft)
vline!([2.3]; linestyle = :dashdot, lw = 3, color = :grey, label = "Kc")
vline!([1 + 2 * 2.3]; linestyle = :dashdot, lw = 3, color = :darkgrey, label = "1 + 2Kc")
savefig("enrichment_orbit-diagram.svg");
nothing; # hide
```

![](enrichment_orbit-diagram.svg)

As described above we observe three parts in this plot.
First, if ``K \leq K_c`` only the resource survives
and has a biomass equal to its carrying capacity.
Secondly, if ``K_c \leq K \leq 1 + 2 K_c`` both species can coexist:
the resource has a constant biomass equal to ``K_c``,
while the consumer biomass increases with the carrying capacity.
Thirdly, if ``K \geq 1 + 2 K_c`` then the system is destabilized and start to oscillate
resulting eventually in the extinction of the species.
