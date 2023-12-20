# The Ecological Model and Components

`EcologicalNetworksDynamics` represents an ecological network
as a julia value of type [`Model`](@ref).

```@setup econetd
using EcologicalNetworksDynamics
```

```@example econetd
m = default_model(Foodweb([:a => :b, :b => :c]))
```
Values of this type essentially describe a *graph*,
with various *nodes* compartments representing
*e.g.* species or nutrients
and various *edges* compartments representing
*e.g.* trophic links, or facilitation links.
In addition to the network topology,
the model also holds *data* describing the model further,
and brought by the various models *components*.
There are three possible "levels" for this data:
- __Graph-level__ data describe properties of the whole system.
  *e.g.*  temperature, hill-exponent *etc.*
  These are typically *scalar* values.
- __Node-level__ data describe properties
  of particular nodes in the graph:
  *e.g.* species body mass, nutrients turnover *etc.*
  These are typically *vector* values.
- __Edge-level__ data describe properties of particular links:
  *e.g.* trophic links efficiency,
  half-saturation of a producer-to-nutrient links *etc.*
  These are typically *matrix* values.

## Model Properties

The data held by the model can be accessed via the various model *properties*,
with functions named `get_<X>`:
```@example econetd
get_hill_exponent(m) # Graph-level data (a number).
```
```@example econetd
get_body_masses(m) # Node-level data (a vector with one value per species).
```
```@example econetd
get_efficiency(m) # Edge-level data (a matrix with one value per species interaction).
```

Alternately, the data can also be accessed
*via* julia's `m.<x>` property accessor:
```@example econetd
m.hill_exponent # Same as get_hill_exponent(m).
m.body_masses   # Same as get_body_masses(m).
m.efficiency    # Same as get_efficiency(m).
nothing # hide
```

Some data can be modified this way,
either with `set_<x>!(m, value)`.
But *not all*:
```@example econetd
# Okay: this is terminal data.
set_hill_exponent!(m, 2.1)
m.hill_exponent = 2.1 # (alternate syntax for the same operation)

try # hide
# Not okay: this could make the rest of the model data inconsistent.
m.species_richness = 4
catch err; print(stderr, "ERROR: "); showerror(stderr, err); end # hide
```

If you need a model with different values for read-only data,
you need to build a new model with the values you desire.
```@example econetd
m = default_model(Foodweb([:a => :b, :b => [:c, :d]])) # Re-construct with a 4th species.
m.species_richness # Now the value is what you want.
```

The full list of available model properties can be queried with:
```@example econetd
properties(m)
nothing # hide
```

## Model Components

The [`Model`](@ref) value is very flexible
and can represent a variety of different networks.
It is made from the combination of various *components*.

### Empty Model and the `add!` Method.

When you start from a [`default_model`](@ref),
you typically obtain a full-fledged value,
with all the components required to simulate the dynamics.
Alternately, you can start from an empty model:

```@example econetd
m = Model()
```

In this situation, you need to add the components one by one.
But this gives you full control over the model content.

An empty model cannot be simulated,
because the data required for simulation is missing from it.
```@example econetd
try # hide
simulate(m, 0.5)
catch err; print(stderr, "ERROR: "); showerror(stderr, err); end # hide
```

Also, an empty model cannot be queried for data,
because there is no data inside:
```@example econetd
try # hide
m.richness
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

The most basic way to add a [`Species`](@ref) component to your model
is to use the [`add!`](@ref) function:
```@example econetd
add!(m, Species(3))
```

Now that the [`Species`](@ref) component has been added,
the related properties can be queried from the model:
```@example econetd
m.richness
```
```@example econetd
m.species_names
```

But the other properties cannot be queried,
because the associated components are still missing:
```@example econetd
try # hide
m.trophic_links
catch err; print(stderr, "ERROR: "); showerror(stderr, err); end # hide
```

Before we add the missing [`Foodweb`](@ref) component,
let us explain that the component addition we did above
actually happened in *two stages*.

### Blueprints Expand into Components.

To add a component to a model,
we first need to create a *blueprint* for the component.
A blueprint is a julia value
containing all the data needed to construct a component.
```@example econetd
sp = Species(3) # This is a blueprint, useful to later expand into a model component.
```

When you call the [`add!`](@ref) function,
you feed it with a model and a blueprint.
The blueprint is read and *expanded* into a component within the given model:
```@example econetd
m = Model() # Empty model.
add!(m, sp) # Expand blueprint `sp` into a `Species` component within `m`.
m           # The result is a model with 1 component inside.
```

As we have seen before: once it has been expanded into the model,
you cannot always edit the component data directly.
For instance, the following does not work:
```@example econetd
try # hide
m.species_names[2] = "rhino"
catch err; print(stderr, "ERROR: "); showerror(stderr, err); end # hide
```

However, you can always edit the *blueprint*,
then re-expand it later into other models.
```@example econetd
sp.names[2] = :rhino    # Edit one species name within the blueprint.
push!(sp.names, :ficus) # Append a new species to the blueprint.
m2 = Model(sp)          # Create a new model from the modified blueprint.
m2                      # This new model contains the alternate data.
```

Blueprints can get sophisticated.
For instance,
here are various ways to create blueprints for a [`Foodweb`](@ref) component.
```@example econetd
fw = Foodweb(:niche, S = 5, C = 0.2) # From a random model.
fw = Foodweb([0 1 0; 1 0 1; 0 0 0])  # From an adjacency matrix.
fw = Foodweb([1 => 2, 2 => 3])       # From an adjacency list.
nothing # hide
```

If you want to test the corresponding `Foodweb` component,
but you don't want to loose the original model,
you can keep a safe [`copy`](@ref) of it
before you actually expand the blueprint:
```@example econetd
base = copy(m) # Keep a safe, basic, incomplete version of the model.
add!(m, fw)    # Expand the foodweb into a new component within `m`: `base` remains unchanged.
nothing # hide
```

A shorter way to do so is to directly use julia's `+` operator,
which always leaves the original model unchanged
and creates an augmented copy of it:
```@example econetd
m = base + fw # Create a new model `m` with a Foodweb inside, leaving model `base` unchanged.
```

Separating blueprints creation from final components expansion
gives you flexibility when creating your models.
Blueprints can either be thrown after use,
or kept around to be modified and reused without limits.

## Model Constraints.

Of course, you cannot expand blueprints into components
that would yield inconsistent models:
```@example econetd
base = Model(Species(3)) # A model a with 3-species compartment.
try # hide
global m # hide
m = base + Foodweb([0 1; 0 0]) # An adjacency matrix with only 2×2 values.
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

Components cannot be *removed* from a model,
because it could lead to inconsistent model values.
Components cannot either be *duplicated* or *replaced* within a model:
```@example econetd
m = Model(Foodweb(:niche, S = 5, C = 0.2))
try # hide
global m # hide
m += Foodweb([:a => :b]) # Nope: already added.
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

If you ever feel like you need
to "change a component" or "remove a component" from a model,
the correct way to do so is to construct a new model
from the blueprints and/or the other base models you have kept around.

Components also *require* each other:
you cannot specify trophic links efficiency in your model
without having first specified what trophic links are:
```@example econetd
m = Model(Species(3))
try # hide
global m # hide
m += Efficiency(4)
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

## Blueprint Nesting (advanced).

To help you not hit the above problem too often,
some blueprints take advantage of the fact
that they contain the information needed
to *also* expand into some of the components they require.
Conceptually, they embed smaller blueprints within them.

For instance, the following blueprint for a foodweb
contains enough information to expand into both a [`Foodweb`](@ref) component,
*and* the associated [`Species`](@ref) component if needed:
```@example econetd
fw = Foodweb([1 => 2, 2 => 3]) # Species nodes can be inferred from this blueprint..
m = Model(fw) # .. a blank model given only this blueprint becomes equiped with the 2 components.
```

So it is not an error to expand the `Foodweb` component
into a model not already having a `Species` compartment.
We say that the `Foodweb` blueprint *implies* a `Species` blueprint.

If you need more species in your model than appear in your foodweb blueprint,
you can still explicitly expand the `Species` blueprint
before you add the foodweb:
```@example econetd
m = Model(Species(5), Foodweb([1 => 2, 2 => 3])) # A model with 2 isolated species.
```

Some blueprints, on the other hand, explicitly *bring* other blueprints.
For instance, the [`LinearResponse`](@ref)
brings both [`ConsumptionRate`](@ref)
and [`ConsumersPreference`](@ref) sub-blueprints:
```@example econetd
lin = LinearResponse()
```

So a model given this single blueprint can expand with 3 additional components.

```@example econetd
m += lin
```

The difference with "implication" though,
is that the sub-blueprints "brought" *do* conflict with existing components:
```@example econetd
m = Model(fw, ConsumptionRate(2)) # This model already has a consumption rate.
try # hide
global m # hide
m += lin # So it is an error to bring another consumption rate with this blueprint.
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

This protects you from obtaining a model value with ambiguous consumption rates.

To prevent the sub-blueprint [`ConsumptionRate`](@ref) from being brought,
you need to explicitly remove it from the blueprint containing it:
```@example econetd
lin.alpha = nothing # Remove the brought sub-blueprint.
lin = LinearResponse(alpha = nothing) # Or create directly without the brought sub-blueprint.
m += lin # Consistent model obtained.
```

# Using the Default Model.

Building a model from scratch can be tedious,
because numerous components are required
for the eventual simulation to take place.

Here is how you could do it
with only temporary blueprints immediately dismissed:
```@example econetd
m = Model(
  Foodweb([:a => :b, :b => :c]),
  BodyMass(1),
  MetabolicClass(:all_invertebrates),
  BioenergeticResponse(),
  LogisticGrowth(),
  Metabolism(:Miele2019),
  Mortality(0),
)
nothing # hide
```

Here is how you could do it
with blueprints that you would keep around
to later reassemble into other models:
```@example econetd
# Basic blueprints saved into variables for later edition.
fw = Foodweb([:a => :b, :b => :c])
bm = BodyMass(1)
mc = MetabolicClass(:all_invertebrates)
be = BioenergeticResponse()
lg = LogisticGrowth()
mb = Metabolism(:Miele2019)
mt = Mortality(0)

# One model with all the associated components.
m = Model() + fw + bm + mc + be + lg + mb + mt
nothing # hide
```

If this is too tedious,
you can use the [`default_model`](@ref) function instead
to automatically create a model with all (or most) components
required for simulation.
The only mandatory argument to [`default_model`](@ref)
is a [`Foodweb`](@ref) blueprint:
```@example econetd
fw = Foodweb([:a => :b, :b => :c])
m = default_model(fw)
```

But you can feed other blueprints into it
to fine-tweak only the parameters you want to modify.
```@example econetd
m = default_model(fw, BodyMass(Z = 1.5), Efficiency(2))
(m.body_masses, m.efficiency)
```

The function [`default_model`](@ref) tries hard
to figure the default model you expect
based on the few blueprints you input.
For instance, it assumes that you need
a different type of functional response
if you input a [`Temperature`](@ref) component,
and temperature-dependent allometry rates:
```@example econetd
m = default_model(fw, Temperature(220))
```

Or if you wish to explicitly represent [`Nutrients`](@ref)
as a separate nodes compartment in your ecological network:
```@example econetd
m = default_model(fw, Nutrients.Nodes(2))
```

But the function will not choose between two similar blueprints
if you bring both, even implicitly:
```@example econetd
try # hide
global m # hide
m = default_model(
  fw,
  BodyMass(Z = 1.5),      # <- Customize body mass.
  ClassicResponse(e = 2), # <- This blueprint also brings a BodyMassy
)
catch e; print(stderr, "ERROR: "); showerror(stderr, e); end # hide
```

In this situation,
either stop implicitly bringing `BodyMass`
with `ClassicResponse(e=2, M=nothing)`,
or directly move you custom body mass input into the larger blueprint:
```@example econetd
m = default_model(
  fw,
  ClassicResponse(e = 2, M = (; Z = 1.5)),
)
```
