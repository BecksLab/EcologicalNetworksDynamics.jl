<p align="center" width="100%">
    <img height="150" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/main/docs/src/assets/logo-and-name.svg#gh-light-mode-only">
    <img height="150" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/main/docs/src/assets/logo-and-name-dark.svg#gh-dark-mode-only">
</p>

EcologicalNetworksDynamics is a Julia package that simulates species biomass dynamics
in ecological networks.
EcologicalNetworksDynamics makes things easy for beginners
while remaining flexible for adventurous or experienced users
who would like to tweak the model.

[![docs](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/actions/workflows/docs.yml/badge.svg?branch=main)](https://beckslab.github.io/EcologicalNetworksDynamics.jl/)
[![tests](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/actions/workflows/tests.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10853978.svg)](https://doi.org/10.5281/zenodo.10853978)

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
create a simple food web with:

```julia
using EcologicalNetworksDynamics
Foodweb([1 => 2]) # Species 1 eats species 2.
```

## Learning EcologicalNetworksDynamics

The [Quick start] page shows
how to simulate biomass dynamics in a simple food web.
The rest of the [Guide] provides a step by step introduction
to the package features,
from the generation of the network structure
to the simulation of the biomass dynamics.
At each step, we detail how the model can be customized at your will.

[Quick start]: https://beckslab.github.io/EcologicalNetworksDynamics.jl/man/quickstart/
[Guide]: https://beckslab.github.io/EcologicalNetworksDynamics.jl/

## Getting help

During your journey learning EcologicalNetworksDynamics,
you might encounter issues.
If so, the best is to open [an issue].
To ensure that we can help you efficiently,
please provide a short description of your problem
and a minimal example to reproduce the error you encountered.

[an issue]: https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues

## How can I contribute?

The easiest way to contribute is to [open an issue]
if you spot a bug, a typo or can't manage to do something.
Another way is to fork the repository,
start working from the `dev` branch,
and when ready, submit a pull request.
The contribution guidelines are detailed
[here](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/dev/CONTRIBUTING.md).

[open an issue]: https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues

## Citing

Please mention `EcologicalNetworksDynamics.jl`
if you use it in research, teaching, or other activities.

## Acknowledgments

`EcologicalNetworksDynamics.jl` benefited from
the Montpellier Bioinformatics Biodiversity platform (MBB)
supported by the LabEx CeMEB,
an ANR "Investissements d'avenir" program (ANR-10-LABX-04-01).

<p align="center" width="100%">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/main/docs/src/assets/isem.png">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/main/docs/src/assets/cnrs.png">
    <img height="100" src="https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/main/docs/src/assets/mbb.png">
</p>
