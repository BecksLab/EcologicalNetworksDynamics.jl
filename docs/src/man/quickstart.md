# Quick start

If it's your first time using EcologicalNetworksDynamics,
exploring this example might be useful to you
so that you understand how the package works.
Try pasting the following code blocks in a Julia REPL.

The first step is to create the structure of the trophic interactions.

```@example quickstart
using EcologicalNetworksDynamics, Plots
fw = Foodweb([1 => 2, 2 => 3]) # 1 eats 2, and 2 eats 3
```

Then, you can generate the parameter of the model (mostly species traits) with:

```@example quickstart
m = default_model(fw)
```

For instance, we can access the species natural mortality rates with:

```@example quickstart
m.mortality
```
**TODO: explain how to get the names of m. Properties(m) does not work. When it does, add this. **

At this step we are ready to run simulations,
we just need to provide initial conditions for species biomasses.

```@example quickstart
B0 = [1, 1, 1] # the 3 species start with a biomass of 1
out = simulate(m, B0)
```

Lastly, we can plot the biomass trajectories:

```@example quickstart
plot(out)
```
