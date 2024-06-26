# Generate Food Webs

Food webs are at the core of this package,
and thus can be generated in various ways depending on your needs.
In the following sections, we will go over the different methods of network generation.
But, first things first, let us see what is inside a [`Foodweb`](@ref).

A [`Foodweb`](@ref) object contains the trophic adjacency matrix `A` filled with 0s and 1s
indicating respectively the absence and presence of trophic interactions.
Rows are consumers and columns resources, thus `A[i,j] = 1` reads "species `i` eats species `j`"

## From an Adjacency Matrix

The most straightforward way to generate a [`Foodweb`](@ref) is to
define your own adjacency matrix (`A`) by hand
and give it to the [`Foodweb`](@ref) method
that will return the corresponding [`Foodweb`](@ref) object.

```@setup econetd
using EcologicalNetworksDynamics
```

```@example econetd
A = [0 0 0; 1 0 0; 0 1 0] # 1 <- 2 <- 3.
foodweb = Foodweb(A)
```

## From an Adjacency List

Sometimes it is more convenient to define the food web using an adjacency list,
because adjacency lists are often more readable than adjacency matrices.
Adjacency lists are a list of pairs, where each pair is a consumer-resource interaction.

For instance, the food web presented in the previous example can be defined as:

```@example econetd
list = [2 => 1, 3 => 2]
foodweb = Foodweb(list)
```

Species can also be named with strings or symbols:

```@example econetd
list = [:eagle => :rabbit, :rabbit => :grass]
foodweb = Foodweb(list)
```

Creating a [`Foodweb`](@ref) from your own adjacency matrix or list is straightforward,
but this is mostly useful for simple and small 'toy systems'.
If you want to work with [`Foodweb`](@ref)s with a large size and a realistic structure,
it is more suitable to create the [`Foodweb`](@ref) using structural models.

## From a Structural Model

You can use the niche, or the cascade model to generate a food web.
The niche model requires a number of species, and either a connectance `C` or a number of links `L`.

```@example econetd
fw1 = Foodweb(:niche; S = 5, C = 0.2)
```

```@example econetd
fw2 = Foodweb(:niche; S = 5, L = 5)
```

The cascade model requires a number of species and a connectance:

```@example econetd
fw3 = Foodweb(:cascade; S = 5, C = 0.2)
```
