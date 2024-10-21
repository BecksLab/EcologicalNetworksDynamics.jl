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

# TODO: These are mostly useless, except for JuliaLS.. ? :(
import EcologicalNetworksDynamics:
    AliasingDicts,
    Allometry,
    BinAdjacency,
    Blueprint,
    Brought,
    EcologicalNetworksDynamics,
    F,
    Internal,
    Internals,
    MetabolicClassDict,
    SparseMatrix,
    SparseVector,
    Topologies,
    check_template,
    imap,
    parse_allometry_arguments,
    refs,
    refspace,
    sparse_nodes_allometry,
    to_dense_vector,
    to_size,
    to_sparse_matrix,
    to_sparse_vector,
    to_template,
    @GraphData,
    @check_list_refs,
    @check_size,
    @check_symbol,
    @check_template,
    @expand_symbol,
    @get,
    @ref,
    @set,
    @tographdata
import .F: checkfails, checkrefails, @blueprint
import .AliasingDicts: AliasingError
