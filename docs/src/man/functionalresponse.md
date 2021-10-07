# The functional response 

The type of functional response used during the simulation can drastically change the model dynamics. Here we show how to change the functional response and its parameters. 

There are 2 main types of implementation for the functional response. One uses the consumers maximum assimilation rates and half saturation densities -- as described in the original description of the model by Yodzis and Innes (1992) -- while the other, more classical formulation, relies on pairwise attack rates and handling times (not implemented yet, work in progress).

## The original functional response (default setting) 

By default, the original formulation of the functional response (Yodzis & Innes, 1992; Williams, Brose and Martinez 2005) is used.

-> TODO: equation

When calling the `ModelParameters` function with default settings, a Holling type III functional response is implemented ($h = 2$ and $c = 0$): 

~~~julia-repl
julia> #define a food web
julia> using EcologicalNetworks
julia> fw = FoodWeb(nichemodel, 20, C = 0.2, Z = 10)
20 species - 87 links. 
 Method: nichemodel
julia> #call the ModelParameters function with default settings
julia> p = ModelParameters(fw)
Model parameters are compiled:
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅
julia> #inspect the FunctionalResponse object
julia> p.FunctionalResponse
functional response: classical
type III
~~~

This is equivalent to calling the `originalFW` function with default values and passing that to `ModelParameters`: 

~~~julia-repl
julia> funcrep = originalFR(fw)
functional response: classical
type III
julia> p = ModelParameters(fw; FR = funcrep)
Model parameters are compiled:
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅
~~~

## The FunctionalResponse object 

The `FunctionalResponse` object contains 6 fields: 

- `functional_response` is the function that will be used during the simulations to calculate the functional response 

~~~julia-repl
julia> p.FunctionalResponse.functional_response
(::BEFWM2.var"#classical#9") (generic function with 1 method)
~~~

- `hill_exponent` (default is 2) is the hill exponent controlling the shape of the functional response: inverse exponential if 1 (Holling type II) and sigmoid if 2 (Holling type III).

~~~julia-repl
julia> p.FunctionalResponse.hill_exponent
2.0
~~~

- `c` is either a vector or a single value expressing the strength of the predator interference(between 0 and 1). `hill_exponent = 1` and `c = 1` describe a Beddington-DeAngelis functional response. 

~~~julia-repl
julia> p.FunctionalResponse.c
20-element Vector{Float64}:
 0.0
 0.0
 ⋮
 0.0
 0.0
~~~

- `e` is a S*S array of pairwise assimilation efficiencies. By default herbivory links have an efficiency of 0.45 and carnivory links 0.85.

~~~julia-repl
julia> p.FunctionalResponse.e
20×20 SparseArrays.SparseMatrixCSC{Float64, Int64} with 87 stored entries:
⠢⠤⠀⠀⠀⠀⠀⠀⠀⠀
⢘⠋⠉⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠶⣉⣁⣀⣀⣀⣀⠀
⢀⣀⣀⠉⠿⠿⠿⠿⠯⠀
⢉⣥⣤⣒⡒⠂⠀⠀⠀⠀
~~~

- `B0` is the half saturation density (consumer-specific)
  
~~~julia-repl
p.FunctionalResponse.B0
20-element Vector{Float64}:
 0.5
 0.5
 ⋮
 0.5
 0.5
~~~

- `ω` is the consumers relative preference for their resources. By default, it is set at $1/n$ where $n$ is the number of resources a consumer has. 

~~~julia-repl
julia> p.FunctionalResponse.ω
20×20 SparseArrays.SparseMatrixCSC{Float64, Int64} with 87 stored entries:
⠢⠤⠀⠀⠀⠀⠀⠀⠀⠀
⢘⠋⠉⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠶⣉⣁⣀⣀⣀⣀⠀
⢀⣀⣀⠉⠿⠿⠿⠿⠯⠀
⢉⣥⣤⣒⡒⠂⠀⠀⠀⠀
~~~

-> Equation for the functional response (and source)
-> consumer-specific rates used (equations, parameter values and sources)
-> simple code example
## The classical functional response 

-> Equation 
-> Equivalence between the two functional response 
-> pairwise-specific rates used (equations, parameter values and sources)
-> simple code example

## Change the parameter values 

-> How to manipulate arguments