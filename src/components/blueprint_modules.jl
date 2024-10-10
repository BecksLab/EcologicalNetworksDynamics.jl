# Factorize numerous imports useful within the blueprint submodules.
# To be `include`d from these modules.

include("./macros_keywords.jl")

# Reassure JuliaLS.
#! format: off
if (false)
    (local
        Species, _Species,
        Foodweb, _Foodweb,

        # Not found for some reason?
        MetabolicClassDict,
        AliasingError,

    var"")
end
#! format: on

import EcologicalNetworksDynamics:
    AliasingDicts,
    BinAdjacency,
    Blueprint,
    Brought,
    EcologicalNetworksDynamics,
    F,
    Internal,
    Internals,
    MetabolicClassDict,
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
    @check_symbol,
    @expand_symbol,
    @get,
    @ref,
    @set,
    @tographdata
import .F: checkfails, checkrefails, @blueprint
import .AliasingDicts: AliasingError
