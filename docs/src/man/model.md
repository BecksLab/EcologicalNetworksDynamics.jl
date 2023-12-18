# How to generate the model parameters?

Once the [`Foodweb`](@ref) is created,
you still have to build the model.


## Use the default set up

The model structure and parameters can be generated automatically by providing only the [`Foodweb`](@ref) as follows:

```@setup econetd
using EcologicalNetworksDynamics
```

```@example econetd
fw = Foodweb([:a => (:b, :c), :b => (:c, :d)])
fw.A  # contains the adjacency matrix
m = default_model(fw)
```

The created model contains a number of components whose list can be seen by typing:
```@example econetd
properties(m)
```

Note that in the default model, the growth is assumed to be logistic and the functional response a bioenergetic one.
Values from individual components can be seen by typing:

```@example econetd
m.A # adjacency matrix
m.richness # number of species
m.species_names
m.r # growth rate
m.K # species' carrying capacities
m.mortality
m.metabolism
```

The model can be run by doing:
```@example econetd
B0 = [0.5, 0.5, 0.5, 0.5]
sol = simulate(m, B0)
```

The dynamics can be visualized:
```@example econetd
using Plots
plot(sol)
```

## Modify the default set up

You can overwrite the default values as follows:

```@example econetd
m = default_model(fw,GrowthRate([0, 0, 2, 3]))
m.growth_rate # which is the same as m.r
m = default_model(fw, BodyMass(1.5))
m.body_mass # which is the same as m.M
m = default_model(fw, BodyMass(1.5), GrowthRateFromAllometry(; a_p = 0.5, b_p = 0.8))
```

You can choose another functional response:
```@example econetd
m = default_model(fw, ClassicResponse())
m.attack_rate
m = default_model(fw, LinearResponse())
m.alpha
```

You can switch to a temperature-dependent model:
```@example econetd
m = default_model(fw, Temperature(290))
```

You can add nutrients (instead of the logistic growth):
```@example econetd
m = default_model(fw, NutrientIntake(; turnover = [1, 2]))
m.n_nutrients
m.nutrients_turnover
m.nutrients_concentration
m.nutrients_supply
```

You can run and visualize the dynamics of the corresponding model:
```@example econetd
B0, N0 = rand(3), rand(2)
sol = simulate(m, B0; N0)
plot(sol)
```

You can add other interaction types:

```@example econetd
m = default_model(fw, CompetitionLayer(; A = (C = 0.2, sym = true), I = 2))

m = default_model(
        fw,
        NontrophicLayers(;
            L = (refuge = 4, facilitation = 6),
            intensity = (refuge = 5, facilitation = 8),
        ),
    )

m = default_model(
        Foodweb([:a => (:b, :c), :d => (:b, :e), :e => :c]),
        NontrophicLayers(;
            L_facilitation = 1,
            C_refuge = 0.8,
            n_links = (cpt = 2, itf = 2),
        ),
    )

m.facilitation_layer_intensity
m.refuge_layer_intensity
m.refuge_links
sum(m.facilitation_links)
```

## Create your own model, component by component

Start from empty model

```@example econetd
m = Model()
```

Add the components one by one:
```@example econetd
add!(m, Foodweb([:a => :b, :b => :c])) # (named adjacency input)
add!(m, BodyMass(1))
add!(m, MetabolicClass(:all_invertebrates))
add!(m, BioenergeticResponse(; w = :homogeneous, half_saturation_density = 0.5))
add!(m, LogisticGrowth(; r = 1, K = 1))
add!(m, Metabolism(:Miele2019))
add!(m, Mortality(0))
```

Simulate the model:

```@example econetd
sol = simulate(m, 0.5) # (all initial values to 0.5)
```

You can also do it in one go:

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
```

Or as follows:
```@example econetd
    fw = Foodweb([:a => :b, :b => :c])
    bm = BodyMass(1)
    mc = MetabolicClass(:all_invertebrates)
    be = BioenergeticResponse()
    lg = LogisticGrowth()
    mb = Metabolism(:Miele2019)
    mt = Mortality(0)

    # Expand them all into the global model.
    m = Model() + fw + bm + mc + be + lg + mb + mt
    # (this produces a system copy on every '+')
```

You add non trophic layers afterwards:

```@example econetd
 m = default_model(
        Foodweb([:a => (:b, :c), :d => (:b, :e), :e => :c]),
        ClassicResponse(),
    )

    # Create the layers so they can be worked on first.
    layers = nontrophic_layers(;
        L_facilitation = 1,
        C_refuge = 0.8,
        n_links = (cpt = 2, itf = 2),
    )

    # Access them with convenience aliases.
    m += layers[:facilitation] + layers[:c] + layers["ref"] + layers['i']
```


** OLD TEXT **

To navigate easily through the parameters,
they are split into a number of components needed:

- [`BodyMass`](@ref) contains the species body masses
- [`MetabolicClass`](@ref) contains the species metabolic classes (among producers, invertebrates and ectotherms)
- [`FunctionalResponse`](@ref) contains the functional response, which can be of three types: bioenergetic, classic or linear
- [`ProducerGrowth`](@ref) contains the growth function of the producers, which can be logictic or based on nutrients consumptions (when nutrients are explicitly present in the model)
- [`Metabolism`](@ref) contains the species metabolic rates
- [`Mortality`](@ref) contains the species mortality rates

In addition, one can define a dependency on temperature and add different types of interactions:
- [`Temperature`](@ref) contains a value of the temperature of the environment (in Kelvin). If a value for it is given, the species biorates depending on temperature are all automatically updated
- [`NonTrophicLayers`](@ref) contains possible additional types of interactions (or layers, in addition to feeding) between species
