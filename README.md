# BioEnergeticFoodWebs 

This package implements Yodzis and Innès (1992) bio-energetic consumer-resource model, adapted to food webs (see Williams, Brose and Martinez, 2008), with added modules. In addition to the core model, we added: 
- various models for basal species growth, including a nutrient uptake function following;
- three different models for adaptive rewiring of trophic interactions following extinctions and/or changes in species biomass;
- various models for accounting for temperature, either on species mass or on their biological rates (growth, metabolism, consumption).

## First simulation 

1. Install the package 

```julia-repl
import Pkg 
Pkg.add("https://github.com/evadelmas/BEFWM2")
using BEFWM2
```

2. Generate a food web

3. Generate the model parameters 

4. Simulate 