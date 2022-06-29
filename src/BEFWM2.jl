module BEFWM2

# Dependencies
using EcologicalNetworks
using SparseArrays
using DiffEqBase
using Mangal
using Statistics
import DifferentialEquations.Tsit5, DifferentialEquations.Rodas4

# Include scripts
include(joinpath(".", "inputs/foodwebs.jl"))
include(joinpath(".", "inputs/nontrophic_interactions.jl"))
include(joinpath(".", "inputs/functional_response.jl"))
include(joinpath(".", "inputs/biological_rates.jl"))
include(joinpath(".", "inputs/environment.jl"))
include(joinpath(".", "model/model_parameters.jl"))
include(joinpath(".", "model/productivity.jl"))
include(joinpath(".", "model/consumption.jl"))
include(joinpath(".", "model/metabolic_loss.jl"))
include(joinpath(".", "model/dbdt.jl"))
include(joinpath(".", "model/simulate.jl"))
include(joinpath(".", "measures/structure.jl"))
include(joinpath(".", "measures/functioning.jl"))
include(joinpath(".", "measures/stability.jl"))
include(joinpath(".", "utils.jl"))

# Export public functions
export FoodWeb, ModelParameters, FunctionalResponse, BioRates, Environment, MultiplexNetwork
export potential_facilitation_links, potential_competition_links, potential_refuge_links
export potential_interference_links, NonTrophicIntensity, Layer
export draw_symmetric_links, draw_asymmetric_links, nontrophic_adjacency_matrix
export homogeneous_preference, BioEnergeticFunctionalResponse
export FunctionalResponse, ClassicResponse, BioenergeticResponse, LinearResponse
export allometric_rate, AllometricParams
export DefaultGrowthParams, DefaultMaxConsumptionParams, DefaultMetabolismParams
export simulate
export cascademodel, nichemodel, nestedhierarchymodel, mpnmodel, richness, links

end
