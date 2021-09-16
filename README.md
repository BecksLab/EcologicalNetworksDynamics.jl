# BioEnergeticFoodWebs 

This package implements Yodzis and Innès (1992) bio-energetic consumer-resource model, adapted to food webs (see Williams, Brose and Martinez, 2008), with added modules. In addition to the core model, we added: 
- various models for basal species growth, including a nutrient uptake function following;
- three different models for adaptive rewiring of trophic interactions following extinctions and/or changes in species biomass;
- various models for accounting for temperature, either on species mass or on their biological rates (growth, metabolism, consumption).

## First simulation 

1. Install the package 

- clone the repository
- open the newly created folder with you preferred code editor
- run the following lines:
```julia-repl
julia> import Pkg 
julia> Pkg.activate(.)
Activating environment at `~/.../BEFWM2/Project.toml`
julia> using BEFWM2
[ Info: Precompiling BEFWM2 [2fd9189a-c387-4076-88b7-22b33b5a4388]
```

1. Generate a food web

See the help function `?FoodWeb` and the documentation in `docs/src/man/foodwebs.md` for more details. 

```julia-repl
julia> using EcologicalNetworks
julia> fw = FoodWeb(nichemodel, 10, C = 0.2, Z = 10)
10 species - 13 links. 
 Method: nichemodel
```

2. Generate the model parameters 

3. Simulate 