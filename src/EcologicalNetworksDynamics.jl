"""
EcologicalNetworksDynamics

Provide tools to simulate biomass dynamics in trophic and multiplex networks.
Trophic networks only include feeding interactions,
while multiplex networks also include non-trophic interactions such as
interference between predators, or plant facilitation.
The basic workflow has been designed to be as simple as possible,
while remaining flexible for the experienced or adventurous user
who would like to refine the model and its parameters.

Example of a simple workflow:

```julia
trophic_backbone = FoodWeb([1 => [2, 3]]) # species 1 eats plants 2 and 3
multi_net = MultiplexNetwork(trophic_backbone; L_facilitation = 1) # add 1 facilitation link
p = ModelParameters(multi_net) # generate model parameters
sol = simulate(p, rand(3)) # run simulation with random initial conditions
```

For more information, either go through the online documentation at (https://doc-url)
or if you are looking for the help of a specific function read its docstring
by writing `?<function_name>` in a Julia REPL.
"""
module EcologicalNetworksDynamics

import DifferentialEquations.Rodas4
import DifferentialEquations.SSRootfind
import DifferentialEquations.Tsit5
using DiffEqBase
using DiffEqCallbacks
using EcologicalNetworks
using Graphs
using Mangal
using OrderedCollections
using SparseArrays
using Statistics
using Decimals
using SciMLBase

const Solution = SciMLBase.AbstractODESolution

include(joinpath(".", "macros.jl"))
include(joinpath(".", "inputs/foodwebs.jl"))
include(joinpath(".", "inputs/nontrophic_interactions.jl"))
include(joinpath(".", "inputs/functional_response.jl"))
include(joinpath(".", "inputs/biological_rates.jl"))
include(joinpath(".", "inputs/environment.jl"))
include(joinpath(".", "inputs/temperature_dependent_rates.jl"))
# include(joinpath(".", "inputs/producer_competition.jl"))
# include(joinpath(".", "inputs/nutrient_intake.jl"))
include(joinpath(".", "inputs/producer_growth.jl"))
include(joinpath(".", "model/model_parameters.jl"))
include(joinpath(".", "model/set_temperature.jl"))
include(joinpath(".", "model/productivity.jl"))
include(joinpath(".", "model/consumption.jl"))
include(joinpath(".", "model/metabolic_loss.jl"))
include(joinpath(".", "model/dbdt.jl"))
include(joinpath(".", "model/nutrient_dynamics.jl"))
include(joinpath(".", "model/generate_dbdt.jl"))
include(joinpath(".", "model/simulate.jl"))
include(joinpath(".", "model/effect_nti.jl"))
include(joinpath(".", "measures/structure.jl"))
include(joinpath(".", "measures/functioning.jl"))
include(joinpath(".", "measures/stability.jl"))
include(joinpath(".", "measures/utils.jl"))
include(joinpath(".", "utils.jl"))
include(joinpath(".", "formatting.jl"))

export @check_between
export @check_greater_than
export @check_in
export @check_lower_than
export @check_size
export A_competition_full
export A_facilitation_full
export A_interference_full
export A_refuge_full
export AllometricParams
export BioEnergeticFunctionalResponse
export BioRates
export BioenergeticResponse
export ClassicResponse
export DefaultGrowthParams
export DefaultMaxConsumptionParams
export DefaultMetabolismParams
export DefaultMortalityParams
export DefaultNIntakeParams
export Environment
export ExponentialBA
export ExponentialBAParams
export ExtinctionCallback
export FoodWeb
export FunctionalResponse
export Layer
export LinearResponse
export LogisticGrowth
export ModelParameters
export MultiplexNetwork
export NIntakeParams
export NoTemperatureResponse
export NonTrophicIntensity
export NutrientIntake
export ProducerCompetition
export TemperatureResponse
export alive_trophic_network
export alive_trophic_structure
export allometric_rate
export attack_rate
export biomass
export boltzmann
export cascademodel
export coefficient_of_variation
export community_cv
export connectance
export cpad
export draw_asymmetric_links
export draw_symmetric_links
export efficiency
export evenness
export exp_ba_attack_rate
export exp_ba_carrying_capacity
export exp_ba_growth
export exp_ba_handling_time
export exp_ba_matrix_rate
export exp_ba_metabolism
export exp_ba_params_to_vec
export exp_ba_vector_rate
export extract_last_timesteps
export find_steady_state
export fitin
export generate_dbdt
export get_alive_species
export get_extinct_species
export get_parameters
export handling_time
export homogeneous_preference
export interaction_names
export is_success
export is_terminated
export ispredator
export isprey
export isproducer
export living_species
export max_trophic_level
export mean_trophic_level
export min_max
export mpnmodel
export multiplex_network_parameters_names
export n_links
export nestedhierarchymodel
export nichemodel
export nontrophic_adjacency_matrix
export nutrient_richness
export nutrients
export population_stability
export potential_competition_links
export potential_facilitation_links
export potential_interference_links
export potential_refuge_links
export predators_of
export preys_of
export producer_growth
export producers
export remove_species
export richness
export set_temperature!
export shannon_diversity
export simpson
export simulate
export species
export species_cv
export species_persistence
export species_richness
export synchrony
export top_predators
export total_biomass
export total_richness
export trophic_classes
export trophic_levels
export trophic_structure
export weighted_mean_trophic_level

end
