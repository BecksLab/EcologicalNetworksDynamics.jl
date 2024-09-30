# Factorize numerous imports useful within the blueprint submodules.
# TODO: craft some `@reexport` macro ? But this would confuse JuliaLS again :\

# Take this opportunity to reassure JuliaLS: these are keywords for the macros.
#  https://github.com/julia-vscode/StaticLint.jl/issues/381#issuecomment-2361743645
if (false)
    local graph, property, get, depends, nodes, edges, ref_cached, requires, E, V, Map, dense
end

module BlueprintModule
import EcologicalNetworksDynamics:
    BinAdjacency,
    Blueprint,
    Brought,
    EcologicalNetworksDynamics,
    F,
    Internal,
    Internals,
    Map,
    SparseMatrix,
    Topologies,
    dense,
    depends,
    imap,
    refs,
    refspace,
    to_dense_vector,
    to_sparse_matrix,
    @GraphData,
    @check_list_refs,
    @check_size,
    @get,
    @ref,
    @set,
    @tographdata
import .F: checkfails, @blueprint
export Blueprint,
    BinAdjacency,
    Brought,
    EcologicalNetworksDynamics,
    F,
    Internal,
    Internals,
    Map,
    SparseMatrix,
    Topologies,
    checkfails,
    dense,
    depends,
    imap,
    refs,
    refspace,
    to_dense_vector,
    to_sparse_matrix,
    @GraphData,
    @blueprint,
    @check_list_refs,
    @check_size,
    @get,
    @ref,
    @set,
    @tographdata
end
