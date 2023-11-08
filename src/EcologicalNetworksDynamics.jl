module EcologicalNetworksDynamics

using Crayons
using DiffEqBase
using MacroTools
using OrderedCollections
using SparseArrays
using Statistics

# ==========================================================================================
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

# ==========================================================================================
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

# ==========================================================================================
# "Abstract" parts: the framework for developing user API.

# The System/Components framework code used for the API is there.
# This module is needed for package component developers.
include("./Framework/Framework.jl")
using .Framework
export add!, properties, blueprints, components

include("./dedicate_framework_to_model.jl")

# ==========================================================================================
# "Outer" parts: develop user-facing stuff here.

#-------------------------------------------------------------------------------------------
# User input: construct the model.

# Components machinery.
include("./kwargs_helpers.jl")
include("./GraphDataInputs/GraphDataInputs.jl")
include("./graph_views.jl")
using .KwargsHelpers
using .GraphDataInputs
using .GraphViews
include("./expose_data.jl")

# Components definition.
include("./components/main.jl")

# Higher-level utils built on top of components.
include("./default_model.jl")
include("./nontrophic_layers.jl")

#-------------------------------------------------------------------------------------------
# Simulation utils.

include("./simulate.jl")

#-------------------------------------------------------------------------------------------
# Post-simulation utils.

include("./analysis/main.jl")

# Avoid Revise interruptions when redefining methods and properties.
Framework.REVISING = true

end
