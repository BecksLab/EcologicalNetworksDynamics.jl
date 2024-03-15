module EcologicalNetworksDynamics

using Crayons
using MacroTools
using OrderedCollections
using SparseArrays

#-------------------------------------------------------------------------------------------
# Shared API internals.
# Most of these should move to the dedicated components files
# once the internals have been refactored to not depend on them.

# Common display utils.
include("./display.jl")
using .Display

# Common error to throw on user input error.
argerr(mess) = throw(ArgumentError(mess))

# Alias common types.
const Option{T} = Union{Nothing,T}
const SparseMatrix{T} = SparseMatrixCSC{T,Int64}

include("./AliasingDicts/AliasingDicts.jl")
using .AliasingDicts

include("./multiplex_api.jl")
using .MultiplexApi

#-------------------------------------------------------------------------------------------
# "Inner" parts: legacy internals.

# The entire implementation has been brutally made private
# so that we can focus on constructing
# an implementation-independent API on top of it, from scratch.
# Once this API is completed, we expect publishing the package,
# the associated article, and then only perform deep refactoring of the "Internals".
include("./Internals/Internals.jl")

# Basic API reconstruction principle:
#   make the package work again,
#   but without re-exporting anything from Internals.
import .Internals

#-------------------------------------------------------------------------------------------
# "Abstract" parts: the framework for developing user API.

# The System/Components framework code used for the API is there.
# This module is needed for package component developers.
include("./Framework/Framework.jl")
using .Framework
export add!, properties, blueprints, components

include("./dedicate_framework_to_model.jl")

#-------------------------------------------------------------------------------------------
# Analysis tools working on the output of the simulation.
include("output-analysis.jl")
export richness
export persistence
export shannon_diversity
export total_biomass

#-------------------------------------------------------------------------------------------
# "Outer" parts: develop user-facing stuff here.

# Factorize out common optional argument processing.
include("./kwargs_helpers.jl")
using .KwargsHelpers

# Factorize out common user input data preprocessing.
include("./GraphDataInputs/GraphDataInputs.jl")
using .GraphDataInputs

# Encapsulated views into internal arrays or pseudo-arrays.
include("./graph_views.jl")
using .GraphViews

# Convenience macro to wire this all together.
include("./expose_data.jl")

# The actual user-facing components of the package are defined there,
# connecting them to the internals via the framework.
include("./components/main.jl")
include("./methods/main.jl")

# Additional exposed utils built on top of components and methods.
include("./default_model.jl")
include("./nontrophic_layers.jl")

# Avoid Revise interruptions when redefining methods and properties.
Framework.REVISING = true

end
