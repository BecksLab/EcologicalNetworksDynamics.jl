# Generating food webs 

The core input for the bio-energetic food-web model is the food web. There are different methods for generating food webs, all return an object of type `FoodWeb` with 5 fields: 
- `A` is a sparse array of boolean values representing the adjacency matrix, with consumers as rows (`i`) and resources in columns (`j`). `A[i,j] = true` if species `i` eats species `j`;
- species is a vector describing species identities 
- `M` is a vector of species body mass 
- `metabolic_class` is a vector describing species metabolic class
- `method` described the method used to build the food web. This is especially useful when using a model (e.g. `nichemodel` from `EcologicalNetworks`) because method will then take automatically take the name of the model, but this can be used to store any information abou the food web (e.g. the source if it is an empirical food web). 

## Using a user defined interaction matrix

~~~julia-repl
julia> #define the adjacency matrix, with consumers as rows. 
julia> #Can be either a SxS Matrix{Bool} or a SxS Matrix{Int64} with 1s and 0s
julia> exp_compet = [false true true; false false false; false false false]
3×3 Matrix{Bool}:
 0  1  1
 0  0  0
 0  0  0
julia> #use FoodWeb to build the FoodWeb object
julia> fw = FoodWeb(exp_compet)
3 species - 2 links. 
Method: unspecified
~~~

Explore the object created: 

- field `A` contains the user-defined adjacency matrix
~~~julia-repl
julia> fw.A
3×3 SparseArrays.SparseMatrixCSC{Bool, Int64} with 2 stored entries:
 ⋅  1  1
 ⋅  ⋅  ⋅
 ⋅  ⋅  ⋅
~~~

- field `species` has not been modified and as such contains default values:
~~~julia-repl
julia> fw.species
3-element Vector{String}:
 "s1"
 "s2"
 "s3"
~~~

- we have not specified species masses nor a consumer-resource mass ratio, so default masses are `1.0`:
~~~julia-repl
julia> fw.M
3-element Vector{Real}:
 1.0
 1.0
 1.0
~~~

- we have not specified species metabolic classes, so default values are used (basal species are producers and other are invertebrates)
~~~julia-repl
julia> fw.metabolic_classes
3-element Vector{String}:
 "invertebrate"
 "producer"
 "producer"
~~~

- the default value for method is `unspecified`
 ~~~julia-repl
julia> fw.method
"unspecified"
~~~

## Using a structural model

The `EcologicalNetworks` package implements various structural models to build food webs. You can pass any of those models, with the corresponding arguments, to generate food webs. 

~~~julia-repl
julia> using EcologicalNetworks
julia> fw = FoodWeb(mpnmodel, 20, C = 0.2, forbidden = 0.1)
20 species - 93 links. 
 Method: mpnmodel
~~~

Note that the `method` field has automatically stored the model used to generate the food web: 

~~~julia-repl
julia> fw.method
"mpnmodel"
~~~

## Pass an EcologicalNetwork object 

`BioEnergeticFoodWebs` is now compatible with `EcologicalNetworks`, so you can directly pass a `UnipartiteNetwork` object to `FoodWeb` without having to convert it first: 

NB: This function is not yet able to attribute a metabolic class, or a mass to species, the following will just pass the adjacency matrix. 

~~~julia-repl
julia> using EcologicalNetworks
julia> N = nz_stream_foodweb()[1]
85×85 (String) unipartite ecological network (L: 227 - Bool)
julia> fw = FoodWeb(N, method = "NZ stream")
85 species - 227 links. 
 Method: NZ stream
~~~

## Define species mass

By default, species mass are all 1.0. To change that, you can use either `M` directly, or use a consumer-resource mass ratio `Z`:

- passing known masses: 
  
~~~julia-repl
julia> S = 10 #richness
10
julia> mass = rand(10) .* 100 #generate a vector of species masses
10-element Vector{Float64}:
 99.56952104238623
 91.39217423569855
 62.516199436785726
 85.86867382077854
  ⋮
 74.34820412205818
 34.29549899551032
 23.336180216802237
julia> fw = FoodWeb(nichemodel, 10, C = 0.15, M = mass)
10 species - 10 links. 
 Method: nichemodel
julia> fw.M == mass
true
~~~

- when using a consumer-resource mass ratio, body masses are calculated as `M = Z .^ (tl .- 1)`, where `tl` is a vector of species trophic levels:

~~~julia-repl
julia> S = 10 #richness
10
julia> fw = FoodWeb(nestedhierarchymodel, 10, C = 0.15, Z = 10)
10 species - 15 links. 
 Method: nestedhierarchymodel
julia> fw.M 
10-element Vector{Real}:
   1.0
 215.44346900318823
 100.0
   1.0
   ⋮
   1.0
  10.0
 215.44346900318823
~~~

## Define species metabolic classes 

Species metabolic classes are important properties in the context of the bio-energetic model because the help define allometric parameter values for calculating the biological rates (driving growth, metabolism and consumption). Informed default values are implemented for producers (basal species), invertebrate consumers and ectotherm vertebrate consumers. If you want to use different classes (such as endotherm vertebrates), you can, but note that you should then provide the corresponding parameters or biological rates when defining the model parameters. 

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

Note that if you provide a metabolic class other than producer for any basal species, this will automatically be changed to producer (and return a Warning): 

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

If you specify "vertebrate" instead of "ectotherm vertebrate", we will ask whether you want to change that to "ectotherm vertebrate", you can decide to change (type y) or not (type n): 

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

Finally, if you decide to use classes other than those 3, we will send you a Warning message but will not change anything:

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


