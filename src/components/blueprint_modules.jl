# Factorize numerous imports useful within the blueprint submodules.
# To be `include`d from these modules.

include("./macros_keywords.jl")

import EcologicalNetworksDynamics:
    BinAdjacency,
    Blueprint,
    Brought,
    EcologicalNetworksDynamics,
    F,
    Internal,
    Internals,
    SparseMatrix,
    Topologies,
    imap,
    refs,
    refspace,
    to_dense_vector,
    to_size,
    to_sparse_matrix,
    @GraphData,
    @check_list_refs,
    @check_size,
    @get,
    @ref,
    @set,
    @tographdata
import .F: checkfails, @blueprint
