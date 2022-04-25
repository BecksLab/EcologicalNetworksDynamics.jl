# How to generate foodwebs?

As indicated by its name,
the key input for the bioenergetic foodweb model is the foodweb.
Foodwebs can be generated with different methods that all return
a [`FoodWeb`](@ref) object containing the 5 following fields:
- `A`: the foodweb adjacency matrix with 0s and 1s
    indicating respectively the absence and presence of trophic interactions.
    Rows are consumers and columns resources,
    thus `A[i,j] = 1` reads "species `i` eats species `j`"
- `species`: vector containing species identities
- `M`: vector containing species body-mass
- `metabolic_class`: vector containing species metabolic class (e.g. "producer")
- `method`: the method used to build the food web.
    This is especially useful when using a method
    (e.g. `nichemodel` from EcologicalNetworks.jl)
    because method will then take automatically take the name of the model,
    but this can also be used to store the source of empirical foodweb.

## Define your own adjacency matrix

The most straightforward way to generate the foodweb is to
define your own adjacency matrix (`A`) by hand
and give it to the [`FoodWeb`](@ref) method
that will return you the corresponding `FoodWeb` object.

```@setup befwm2
using BEFWM2
```

```@repl befwm2
A = [0 0 0; 1 0 0; 0 1 0] # 1 producer ⋅ 2 eats 1 ⋅ 3 eats 2
foodweb = FoodWeb(A)
```

We can check that adjacency matrix stored in `foodweb` corresponds to the one we provided.

```@repl befwm2
foodweb.A
```

As we did not use a method (e.g. the `nichemodel`) to create the foodweb,
the method is said to be `unspecified`.

```@repl befwm2
foodweb.method
```

Moreover, by default:
- the consumers are assumed to be inverterbrates

```@repl befwm2
foodweb.metabolic_class
```

- all body-mass are set to 1

```@repl befwm2
foodweb.M
```

- the `species` vector stores only species indexes as no identities were provided.

```@repl befwm2
foodweb.species
```

Creating a foodweb from your own adjacency matrix is straightforward
but is only useful for simple and small 'toy systems'.
If you want to work with foodwebs with a large size and a realistic structure,
it is more suited to create the foodweb using structural models.

## Use a structural model

[EcologicalNetworks.jl](http://docs.ecojulia.org/EcologicalNetworks.jl/stable/) package
implements various structural models to build foodwebs.
You can pass any of those models, with the adequate arguments, to generate foodwebs.

```@repl befwm2
using EcologicalNetworks
S = 20; # number of species
C = 0.2; # connectance
foodweb = FoodWeb(nichemodel, S, C=C)
```

!!! note
    The `method` field has automatically stored the model used to generate the foodweb.

    ```julia-repl
    julia> foodweb.method
    "nichemodel"
    ```

## Provide a unipartite network from EcologicalNetworks.jl

BioenergeticFoodwebs.jl is compatible with EcologicalNetworks.jl,
so you can directly give a `UnipartiteNetwork` object to the [`FoodWeb`](@ref) method.

!!! note
    This function is not yet able to attribute metabolic classes or a mass to species,
    it just pass the adjacency matrix.

```@repl befwm2
unipartite_network = EcologicalNetworks.nz_stream_foodweb()[1] # load network
foodweb = FoodWeb(unipartite_network, method="NZ stream")
```

## Specify species mass

By default all species mass are set to 1.
However, you cange that either by giving your own body-mass vector (`M`).

```@repl befwm2
A = [0 0 0; 1 0 0; 0 1 0]; # define adjacency matrix
M = rand(3) # body-mass are drawn randomly in [0,1]
foodweb = FoodWeb(A, M=M)
foodweb.M
```

Or by using a consumer-resource mass ratio `Z`,
then mass will be computed using species trophic levels (``t_l``)
such that: ``M = Z^{t_l - 1}``.

```@repl befwm2
A = [0 0 0; 1 0 0; 0 1 0]; # trophic levels are respectively 1, 2 and 3
foodweb = FoodWeb(A, Z=10)
foodweb.M
```

## Specify species metabolic classes

!!! note "Todo"
    Update this subsection.

Species metabolic classes are important properties in the context of the bioenergetic model
because the help define allometric parameter values for calculating the biological rates
(driving growth, metabolism and consumption). Informed default values are implemented for
producers (basal species), invertebrate consumers and ectotherm vertebrate consumers. If you
want to use different classes (such as endotherm vertebrates), you can, but note that you
should then provide the corresponding parameters or biological rates when defining the model
parameters.

~~~julia-repl
julia> N = [
 0  0  0  0  0  ;
 0  0  0  0  0  ;
 1  1  0  0  0  ;
 0  0  1  0  0  ;
 0  0  1  1  0
]
julia> metab = ["producer", "producer", "invertebrate", "ectotherm vertebrate", "ectotherm vertebrate"]
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "ectotherm vertebrate"
 "ectotherm vertebrate"
julia> fw = FoodWeb(N, metabolic_class = metab)
5 species - 5 links.
 Method: unspecified
~~~

Note that if you provide a metabolic class other than producer for any basal species,
this will automatically be changed to producer (and return a Warning):

~~~julia-repl
julia> metab = ["producer", "invertebrate", "invertebrate", "ectotherm vertebrate", "ectotherm vertebrate"]
5-element Vector{String}:
 "producer"
 "invertebrate"
 "invertebrate"
 "ectotherm vertebrate"
 "ectotherm vertebrate"
julia> fw = FoodWeb(N, metabolic_class = metab)
┌ Warning: You provided a metabolic class for basal species - replaced by producer
└ @ BEFWM2 ~/projets/BEFWM2/src/inputs/foodwebs.jl:28
5 species - 5 links.
 Method: unspecified
julia> fw.metabolic_class
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "ectotherm vertebrate"
 "ectotherm vertebrate"
~~~

If you specify "vertebrate" instead of "ectotherm vertebrate", we will ask whether you want
to change that to "ectotherm vertebrate", you can decide to change (type y) or not (type n):

~~~julia-repl
julia> metab = ["producer", "producer", "invertebrate", "vertebrate", "vertebrate"]
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "vertebrate"
 "vertebrate"
julia> fw = FoodWeb(N, metabolic_class = metab)
Do you want to replace vertebrates by ectotherm vertebrates (y or n)?y
5 species - 5 links.
 Method: unspecified
julia> fw.metabolic_class
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "ectotherm vertebrate"
 "ectotherm vertebrate"
~~~

Finally, if you decide to use classes other than those 3, we will send you a Warning message
but will not change anything:

~~~julia-repl
julia> metab = ["producer", "producer", "invertebrate", "endotherm vertebrate", "endotherm vertebrate"]
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "endotherm vertebrate"
 "endotherm vertebrate"
julia> fw = FoodWeb(N, metabolic_class = metab)
┌ Warning: No default methods for metabolic classes outside of producers, invertebrates and ectotherm vertebrates, proceed with caution
└ @ BEFWM2 ~/projets/BEFWM2/src/inputs/foodwebs.jl:39
5 species - 5 links.
 Method: unspecified
julia> fw.metabolic_class
5-element Vector{String}:
 "producer"
 "producer"
 "invertebrate"
 "endotherm vertebrate"
 "endotherm vertebrate"
~~~
