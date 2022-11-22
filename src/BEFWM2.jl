module BEFWM2

# Dependencies
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


# Include scripts
include(joinpath(".", "macros.jl"))
include(joinpath(".", "inputs/foodwebs.jl"))
include(joinpath(".", "inputs/nontrophic_interactions.jl"))
include(joinpath(".", "inputs/functional_response.jl"))
include(joinpath(".", "inputs/biological_rates.jl"))
include(joinpath(".", "inputs/environment.jl"))
include(joinpath(".", "inputs/temperature_dependent_rates.jl"))
include(joinpath(".", "inputs/producer_competition.jl"))
include(joinpath(".", "model/model_parameters.jl"))
include(joinpath(".", "model/set_temperature.jl"))
include(joinpath(".", "model/productivity.jl"))
include(joinpath(".", "model/consumption.jl"))
include(joinpath(".", "model/metabolic_loss.jl"))
include(joinpath(".", "model/dbdt.jl"))
include(joinpath(".", "model/generate_dbdt.jl"))
include(joinpath(".", "model/simulate.jl"))
include(joinpath(".", "model/effect_nti.jl"))
include(joinpath(".", "measures/structure.jl"))
include(joinpath(".", "measures/functioning.jl"))
include(joinpath(".", "measures/stability.jl"))
include(joinpath(".", "measures/utils.jl"))
include(joinpath(".", "utils.jl"))
include(joinpath(".", "formatting.jl"))

# Export public functions
export @check_between
export @check_greater_than
export @check_in
export @check_lower_than
export @check_size
export A_competition_full
export A_facilitation_full
export A_interference_full
export A_refuge_full
export allometric_rate
export AllometricParams
export attack_rate
export BioEnergeticFunctionalResponse
export BioenergeticResponse
export BioRates
export boltzmann
export cascademodel
export ClassicResponse
export coefficient_of_variation
export connectance
export cpad
export DefaultGrowthParams
export DefaultExpBAGrowthParams
export DefaultExpBAMetabolismParams
export DefaultExpBAHandlingTimeParams
export DefaultExpBAAttackRateParams
export DefaultExpBACarryingCapacityParams
export DefaultMaxConsumptionParams
export DefaultMetabolismParams
export DefaultMortalityParams
export draw_asymmetric_links
export draw_symmetric_links
export efficiency
export Environment
export ExponentialBA
export exponentialBA_matrix_rate
export exponentialBA_vector_rate
export ExponentialBAParams
export exponentialBAparams_to_vec
export ExtinctionCallback
export find_steady_state
export fitin
export FoodWeb
export foodweb_cv
export foodweb_evenness
export foodweb_richness
export foodweb_shannon
export foodweb_simpson
export FunctionalResponse
export FunctionalResponse
export generate_dbdt
export get_extinct_species
export get_parameters
export handling_time
export homogeneous_preference
export interaction_names
export Layer
export LinearResponse
export ModelParameters
export mpnmodel
export multiplex_network_parameters_names
export MultiplexNetwork
export n_links
export nestedhierarchymodel
export nichemodel
export nontrophic_adjacency_matrix
export NonTrophicIntensity
export NoTemperatureResponse
export population_stability
export potential_competition_links
export potential_facilitation_links
export potential_interference_links
export potential_refuge_links
export predators_of
export preys_of
export producer_growth
export ProducerCompetition
export producers
export richness
export set_temperature!
export simulate
export species_persistence
export species_richness
export TemperatureResponse
export total_biomass
export trophic_levels

end
