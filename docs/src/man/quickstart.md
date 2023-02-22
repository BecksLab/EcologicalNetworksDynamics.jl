# Quick start

If it's your first time using EcologicalNetworksDynamics,
exploring this example might be useful to you
so that you understand how the package works.
Try pasting the following code blocks in a Julia REPL.

The first step is to create the structure of the trophic interactions.

```@example quickstart
using EcologicalNetworksDynamics, Plots
fw = FoodWeb([1 => 2, 2 => 3]) # 1 eats 2, and 2 eats 3
```

Then, you can generate the parameter of the model (mostly species traits) with:

```@example quickstart
p = ModelParameters(fw)
```

For instance, we can access the species metabolic rate (``x``).

```@example quickstart
p.biorates.x
```

At this step we are ready to run simulations,
we just need to provide initial conditions for species biomasses.

```@example quickstart
B0 = [1, 1, 1] # the 3 species start with a biomass of 1
out = simulate(p, B0)
```

Lastly, we can plot the biomass trajectories.

```@example quickstart
plot(out)
```
