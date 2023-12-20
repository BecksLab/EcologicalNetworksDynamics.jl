# Quick start

If it's your first time using EcologicalNetworksDynamics,
exploring this example might be useful to you
so that you understand how the package works.
Try pasting the following code blocks in a Julia terminal.

The first step is to create the structure of the trophic interactions.

```@example quickstart
ENV["GKSwstype"] = "100" # See https://documenter.juliadocs.org/stable/man/syntax/ # hide
using EcologicalNetworksDynamics, Plots
fw = Foodweb([1 => 2, 2 => 3]) # 1 eats 2, and 2 eats 3.
```

Then, you can generate the parameter of the model (mostly species traits) with:

```@example quickstart
m = default_model(fw)
```

For instance, we can access the species metabolic rates with:

```@example quickstart
m.metabolism
```

We see that while consumers (species 1 and 2) have a positive metabolic rate,
producer species (species 3) have a null metabolic rate.

Use `properties` to list all properties of the model:

```@example quickstart
properties(m)
```

At this step we are ready to run simulations,
we just need to provide initial conditions for species biomasses.

```@example quickstart
B0 = [0.1, 0.1, 0.1] # The 3 species start with a biomass of 0.1.
t = 100 # The simulation will run for 100 time units.
out = simulate(m, B0, t)
```

Lastly, we can plot the biomass trajectories using the `plot` functions of [Plots](https://docs.juliaplots.org/latest/).

```@example quickstart
plot(out)
savefig("quickstart.png"); nothing # hide
```

![Quickstart plot](quickstart.png)
