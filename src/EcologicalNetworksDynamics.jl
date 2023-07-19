module EcologicalNetworksDynamics

# The entire implementation has been brutally made private
# so that we can focus on constructing
# an implementation-independent API on top of it, from scratch.
# Once this API is completed, we expect publishing the package,
# the associated article, and then only perform deep refactoring of the "Internals".
include("./Internals/Internals.jl")

# Basic API reconstruction principle:
#   make the package work again,
#   but without re-exporting anything from Internals.
using .Internals


end
