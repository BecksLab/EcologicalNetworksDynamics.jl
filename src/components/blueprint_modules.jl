# Factorize numerous imports useful within the blueprint submodules.
# To be `include`d from these modules.

using SparseArrays
using EcologicalNetworksDynamics
const EN = EcologicalNetworksDynamics
const F = EcologicalNetworksDynamics.Framework
import EcologicalNetworksDynamics:
    AliasingDicts,
    Blueprint,
    Internals,
    SparseMatrix,
    Topologies,
    imap,
    sparse_nodes_allometry,
    @get,
    @ref
import .F: @blueprint, checkfails, Brought, checkrefails
using .EN.AliasingDicts
using .EN.AllometryApi
using .EN.GraphDataInputs
