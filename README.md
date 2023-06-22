<p align="center" width="100%">
    <img height="150" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/readme/docs/src/assets/ecologicalnetworksdynamics.svg#gh-light-mode-only">
    <img height="150" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/readme/docs/src/assets/ecologicalnetworksdynamics-dark.svg#gh-dark-mode-only">
</p>

EcologicalNetworksDynamics is a Julia package that simulates species biomass dynamics
in ecological networks.
EcologicalNetworksDynamics makes things easy for beginners
while remaining flexible for adventurous or experienced users
who would like to tweak the model.

## Before you start

Before anything else, to use EcologicalNetworksDynamics you have to install Julia.
For that go to the [official download page](https://julialang.org/downloads/).
Once you have successfully installed Julia,
you can install the library by running from a Julia REPL:

```julia
using Pkg
Pkg.add("EcologicalNetworksDynamics")
```

To check that the package installation went well,
you can create a simple food web with:

```julia
using EcologicalNetworkDynamics
FoodWeb([1 => 2]) # Species 1 eats species 2.
```

## Learning EcologicalNetworkDynamics

The [Quick start](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/XXX)
page shows how to simulate biomass dynamics in a simple food web.
The rest of the
[Guide](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/XXX)
provides a step by step introduction to the package features,
from the generation of the network structure to the simulation of the biomass dynamics.
At each step, we detail how the model can be customized at your will.
Lastly, the [Tutorials](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/XXX)
section contains realistic use-cases of EcologicalNetworksDynamics.

## Getting help

During your journey learning EcologicalNetworksDynamics you might encounter issues.
If so the best is to open
[an issue](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues).
To ensure that we can help you efficiently,
please provide a short description of your problem
and a minimal example to reproduce the error you encountered.

## How can I contribute?

The easiest way to contribute is to
[open an issue](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues)
if you spot a bug, a typo or can't manage to do something.
Another way is to fork the repository,
start working from the `dev` branch,
and when ready, submit a pull request.
The contribution guidelines are detailed
[here](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/dev/CONTRIBUTING.md).

## Citing

Please mention EcologicalNetworksDynamics
if you use it in research, teaching, or other activities.

## Acknowledgments

EcologicalNetworksDynamics.jl benefited from
the Montpellier Bioinformatics Biodiversity platform (MBB) supported by the LabEx CeMEB,
an ANR "Investissements d'avenir" program (ANR-10-LABX-04-01).

<p align="center" width="100%">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/readme/docs/src/assets/isem.png">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/readme/docs/src/assets/cnrs.png">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/readme/docs/src/assets/mbb.png">
</p>
