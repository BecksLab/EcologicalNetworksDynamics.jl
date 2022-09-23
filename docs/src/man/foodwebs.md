# How to generate food webs?

Food webs are at the core of this package,
and thus can be generated in various ways depending on your needs.
We will go in the following sections over the different generation methods.
But, first things first, let's see what is inside a [`FoodWeb`](@ref).

A [`FoodWeb`](@ref) object always contains the 5 following fields:

  - `A`: the trophic adjacency matrix filled with 0s and 1s
    indicating respectively the absence and presence of trophic interactions.
    Rows are consumers and columns resources,
    thus `A[i,j] = 1` reads "species `i` eats species `j`"
  - `species`: vector containing species identities (e.g. good place to store species names)
  - `M`: vector of species individual body-mass
  - `metabolic_class`: vector of species metabolic class (e.g. "producer")
  - `method`: the method used to build the food web.
    This is especially useful when using a structural model
    (e.g. `nichemodel` from EcologicalNetworks.jl)
    because it will then take automatically take the name of the model,
    but this can also be used to store the source of empirical food web.

## From an adjacency matrix

The most straightforward way to generate the [`FoodWeb`](@ref) is to
define your own adjacency matrix (`A`) by hand
and give it to the [`FoodWeb`](@ref) method
that will return you the corresponding [`FoodWeb`](@ref) object.

```@setup befwm2
using BEFWM2
```

```@example befwm2
A = [0 0 0; 1 0 0; 0 1 0] # 1 <- 2 <- 3
foodweb = FoodWeb(A)
```

We can check that adjacency matrix stored in [`FoodWeb`](@ref)
corresponds to the one we provided.

```@example befwm2
foodweb.A == A
```

Moreover, you can see that by default all body-masses are set to 1
and that species names correspond to their index.

```@example befwm2
foodweb.M
```

```@example befwm2
foodweb.species
```

But you can change that behavior
by providing additional argument to [`FoodWeb`](@ref).

```@example befwm2
foodweb = FoodWeb(A; species = ["plant", "herbivore", "predator"], Z = 50)
foodweb.species
```

```@example befwm2
foodweb.M
```

You see that species names now correspond to the ones that you provided.
For the body-masses it is a little bit trickier.
We use the trophic level (``T``) of each species to set their body-mass such that:
``M = Z^{T-1}``.
Thus, the for the plant as ``T = 1`` its body-mass is set to ``M = 1``,
for the herbivore ``T = 2`` then its body-mass is set to ``M = 50``
and lastly for the predator ``T = 3`` then its body-mass is set to ``M = 2500``.

Obviously, you can also directly provided your own vector of body-masses.
For instance

```@example befwm2
foodweb = FoodWeb(A; M = [1, 10, 50])
foodweb.M
```

Moreover, you can also customize metabolic classes
as they determine the allometric scaling parameters of the bioenergetic model.
By default, basal species are `"producer"`s
and non-basal species are `"invertebrate"`s.

```@example befwm2
foodweb.metabolic_class
```

Let's change `"invertebrate"` into `"ectotherm vertebrates"`.

```@example befwm2
custom_class = ["producer", "ectotherm vertebrate", "ectotherm vertebrate"]
foodweb = FoodWeb(A; metabolic_class = custom_class)
foodweb.metabolic_class
```

When you customize metabolic classes there are 2 rules that you should know.
First, basal species are always set to `"producer"` even if you not say so.

```@example befwm2
custom_class = ["invertebrate", "ectotherm vertebrate", "ectotherm vertebrate"]
foodweb = FoodWeb(A; metabolic_class = custom_class)
foodweb.metabolic_class
```

Secondly, the only three valid metabolic classes are:
`"producer"`, `"invertebrate"` and `"ectotherm invertebrate"`.

Creating a [`FoodWeb`](@ref) from your own adjacency matrix is straightforward
but is mostly useful for simple and small 'toy systems'.
If you want to work with [`FoodWeb`](@ref)s with a large size and a realistic structure,
it is more suited to create the [`FoodWeb`](@ref) using structural models.

## From a structural model

[EcologicalNetworks.jl](http://docs.ecojulia.org/EcologicalNetworks.jl/stable/) package
implements various structural models to build food webs.
You can pass any of those models, with the adequate arguments, to generate food webs.

```@example befwm2
using EcologicalNetworks
S = 20 # species richness
C = 0.2 # connectance
foodweb = FoodWeb(nichemodel, S; C = C)
```

Moreover, the `method` field has automatically stored
the model used to generate the food web.

```@example befwm2
foodweb.method
```

## From a `UnipartiteNetwork` of EcologicalNetworks.jl

EcologicalNetworkDynamics.jl has been thought to interact nicely with EcologicalNetworks.jl,
so you can directly give a `UnipartiteNetwork` object to the [`FoodWeb`](@ref) method.

```@example befwm2
uni_net = EcologicalNetworks.nz_stream_foodweb()[1] # load network
foodweb = FoodWeb(uni_net; method = "NZ stream")
```

You can see that species names have been automatically filled
with the names provided in the `UnipartiteNetwork`.

```@example befwm2
foodweb.species == uni_net.S
```
