# BioEnergeticFoodWebs 

This package implements Yodzis and Innès (1992) bio-energetic consumer-resource model, adapted to food webs (see Williams, Brose and Martinez, 2008), with added modules. In addition to the core model, we added: 
- various models for basal species growth, including a nutrient uptake function following;
- three different models for adaptive rewiring of trophic interactions following extinctions and/or changes in species biomass;
- various models for accounting for temperature, either on species mass or on their biological rates (growth, metabolism, consumption).

## First simulation 

1. **Install the package** 

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

2. **Generate a food web**

See the help function `?FoodWeb` and the documentation in `docs/src/man/foodwebs.md` for more details. 

```julia-repl
julia> using EcologicalNetworks

julia> fw = FoodWeb(nichemodel, 10, C = 0.2, Z = 10)
10 species - 27 links. 
 Method: nichemodel
```

3. **Generate the model parameters** 

```julia-repl
julia> p = ModelParameters(fw)
Model parameters are compiled:
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅
```

*Manipulate the functional response*

The functional response can be manipulated independently:

```julia-repl
julia> funcrep = originalFR(fw, hill_exponent = 1.0, interference = 1.0, B0 = 0.5, e_herbivore = 0.6, e_carnivore = 0.8)
functional response: classical
type II

julia> p = ModelParameters(fw; FR = funcrep)
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅
```

*Manipulate the environmental context*

You can change the temperature and the carrying capacity of the environment. 

Note: Temperature effect is not yet implemented, so changing it won't affect the system's dynamics.

```julia-repl
julia> env = Environment(fw, K = 10)
K (carrying capacity): 10, ..., 0
T (temperature in Kelvins - 0C = 273.15K): 293.15 K
```

*Manipulate the biological rates*

You can change how the biological rates driving the dynamics of the system are calculated, as well as the corresponding parameters. 

Note: Botltzman-Arrhenius equations for biological rates coming soon.  

```juli-repl
julia> r = allometricgrowth(fw, a = 0.5, b = -0.2) #change the constant and the exponent, same for all producers
10-element Vector{Float64}:
 0.5
 0.0
 ⋮
 0.0
 0.0

julia> x = allometricmetabolism(fw, b_p = -0.25, b_ect = -0.3, b_inv = -0.3) #p: producers, ect: ectotherm vertebrates, inv: invertebrates. Pass different exponents for each
10-element Vector{Float64}:
 0.0
 0.15737279135896348
 ⋮
 0.052111028893539406
 0.07234851944815356

julia> y = fill(8.0, richness(fw))
10-element Vector{Float64}:
 8.0
 8.0
 ⋮
 8.0
 8.0

julia> br = BioRates(fw, r = r, x = x, y = y)
r (growth rate): 0.5, ..., 0.0
x (metabolic rate): 0.0, ..., 0.07234851944815356
y (max. consumption rate): 8.0, ..., 8.0
```

*Pass the changed parameters to ModelParameters*

```julia-repl
julia> pmodif = ModelParameters(fw, BR = br, E = env, FR = funcrep)
Model parameters are compiled:
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅
```

4. **Simulate biomass dynamics**

```julia-repl
julia> sim = simulate(p, rand(10), stop = 3000)
(ModelParameters = Model parameters are compiled:
FoodWeb - ✅
BioRates - ✅
Environment - ✅
FunctionalResponse - ✅, t = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25  …  2997.75, 2998.0, 2998.25, 2998.5, 2998.75, 2999.0, 2999.25, 2999.5, 2999.75, 3000.0], B = [0.4037265965996495 0.9490811469685372 … 0.90872709594217 0.12764503860140985; 0.36151508015693096 0.8567569143007236 … 0.9706820816438481 0.1427754269328259; … ; 0.21833151979296234 0.03231501165552453 … 7.0098700884847e38 8.3970945325706; 0.21832905925197701 0.032315234292151225 … 7.060779847806711e38 8.397080475987712])
```

