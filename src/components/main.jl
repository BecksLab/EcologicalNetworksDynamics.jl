# Since we haven't refactored the internals yet,
# the components described here are just a raw embedding of the former 'Internal' interface,
# nicknamed 'raw' in components code.
# Take this opportunity to pick stable names and encapsulate the whole 'Internals' module,
# so we can refactor it later, *deeply*,
# hopefully without needing to change any exposed component/method.

# Mostly, separate "data" components (typically, biorates)
# from "functional" components (typically functional responses):
# data components bring data to the model,
# while functional components specify the behaviour of the model
# based on the data they depend on.
# TODO: reify these two sorts of components?
#       In the end: data requires behaviour and other data to be *built*,
#       so it's a blueprint expansion requirement,
#       but behaviour requires data to be *ran*, so it's a true component requirement?

#-------------------------------------------------------------------------------------------
# About component typing.

# Input to components constructors is desired to be flexible,
# so it needs to be thoroughly checked.
# However, it cannot be fully checked
# until the model value becomes available within the `check` function.
# In addition, early checking with guards on component constructors
# could be defeated by the user later mutating the component.

# The consequence is that component field types reflect this flexibility:
# they cannot be concrete because eg. biorates can either be specified
# with one single float value or a full-fledge vector.
# They could be `Any` but this would allow `biorates.value = "invalid type"`,
# which is easily disallowed by specifying
# sophisticated union types on component fields instead of just `Any`.

# The module GraphDataInputs is useful in this respect.
#-------------------------------------------------------------------------------------------

# To best understand subsequent code,
# and until proper documentation is written,
# I would advise that the following files be skimmed in order
# as later comments build upon earlier ones.

# Inspire from future refactoring into nodes "compartments".
# These are not reified yet into the internals,
# but the following components emulate them.

# TODO there is heavy replication going on in components specification,
# and boilerplate that could be greatly reduced
# once the legacy internals have refactored and simplified.
# Maybe only a few archetypes components are needed:
#   - Graph data.
#   - Nodes.
#   - Dense nodes data.
#   - Sparse (templated) nodes data.
#   - Edges.
#   - Dense edges data.
#   - Sparse (templated) edges data.
#   - Behaviour (graph data that actually represents *code* to run the model).

# Behaviour blueprints typically "optionally bring" other blueprints.
# This utils factorizes how args/kwargs are passed from its inner constructor
# to each of its fields.
include("./args_to_fields.jl")

# HERE: Now that the framework has been refactored,
# change all the following components with the following design:
#
#   module OmegaBlueprints
#      # /!\ many redundant imports to factorize here.
#      struct Raw <: Blueprint ... end
#      struct Random <: Blueprint ... end
#      @blueprint Raw
#      @blueprint Random
#      ...
#   end
#
#   @component Omega blueprints(Raw::OmegaBlueprints.Raw, Random::OmegaBlueprints.Random, ..)
#
#   function (C::_Omega)(args...; kwargs...)
#      if ..
#          C.Raw(...)
#      elseif ...
#          C.Random(...)
#      else ...
#      end
#   end
#
#   # Use as a blueprint constructor, but also as a blueprint namespace.
#   Omega(...)
#   Omega.Random(...)
#   Omega.Raw(...)
#

include("./macros_keywords.jl")

# Central in the model nodes.
include("./species.jl")

# Trophic links, structuring the whole network.
include("./foodweb.jl")

# Biorates and other values parametring the ODE.
include("./body_mass.jl")
#  include("./metabolic_class.jl")

#  # Useful temporary values to calculate other biorates.
#  include("./temperature.jl")

#  include("./allometry.jl")

#  # Models (with comments etc.)
#  include("./hill_exponent.jl") # Example graph-level data.
#  include("./growth_rate.jl") # Example nodes-level data.
#  include("./efficiency.jl") # Example edges-level data.

#  # Replicated/adapted from the above.
#  include("./carrying_capacity.jl")
#  include("./mortality.jl")
#  include("./metabolism.jl")
#  include("./maximum_consumption.jl")
#  include("./producers_competition.jl")
#  include("./consumers_preferences.jl")
#  include("./handling_time.jl")
#  include("./attack_rate.jl")
#  include("./half_saturation_density.jl")
#  include("./intraspecific_interference.jl")
#  include("./consumption_rate.jl")

#  # Namespace nutrients data.
#  include("./nutrients/main.jl")
#  export Nutrients

#  include("./nontrophic_layers/main.jl")
#  using .NontrophicInteractions
#  export NontrophicInteractions
#  export CompetitionLayer
#  export FacilitationLayer
#  export RefugeLayer
#  export InterferenceLayer

#  # The above components mostly setup *data* within the model.
#  # In the nex they mostly specify the *code* needed to simulate it.
#  include("./producer_growth.jl")
#  include("./functional_responses.jl")
#  # Metabolism and Mortality are also code components,
#  # but they are not reified yet and only reduce
#  # to the single data component they each bring.
