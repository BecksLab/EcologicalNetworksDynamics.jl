module Topologies

using OrderedCollections
using SparseArrays

argerr(mess) = throw(ArgumentError(mess))

# Mark removed nodes.
struct Tombstone end

"""
Values of this type are constructed from a model value,
to represent its pure topology:

  - Nodes identity and types: species, nutrients, patches..
  - Edges types: trophic interaction, non-trophic interactions, migrations..

They are supposed not to be mutated,
as they carry faithful topological information reflecting the model
at the moment it has been extracted from it.
Nodes and edge information can be queried from it using either labels or indices.
They *may* be removed to represent *e.g.* species extinction,
and study topological consequences or removing them.
But the indices and labels remain stable,
always consistent with their indices from the model value when extracted.
As a consequence, every node in the topology
can be queried for having been 'removed' or not: tombstones remain.
No tombstone remain for edges: once removed, there is no trace left of them.
"""
struct Topology
    # List/index possible types for nodes and edges.
    # Types cannot be removed.
    node_types_labels::Vector{Symbol} # [type index: type label]
    node_types_index::Dict{Symbol,Int} # {type label: type index}
    edge_types_labels::Vector{Symbol}
    edge_types_index::Dict{Symbol,Int}

    # List nodes and their associated types.
    # Nodes are *sorted by type*:
    # so that all nodes with the same type are stored contiguously in this array.
    # Nodes can't be removed from this list, so the indexes remain stable.
    nodes_labels::Vector{Symbol} # [node index: node label]
    nodes_index::Dict{Symbol,Int} # {node label: node index}
    nodes_types::Vector{UnitRange{Int}} # [type index: (start, end) of nodes with this type]

    # Topological information: paired, layered adjacency lists.
    # Tombstones marking nodes removal are stored here.
    outgoing::Vector{Union{Tombstone,Vector{OrderedSet{Int}}}}
    incoming::Vector{Union{Tombstone,Vector{OrderedSet{Int}}}}
    # [node: [edgetype: {nodeid}]]
    # ^--------------------------^- : Adjacency list: one entry per node 'N'.
    #        ^-------------------^- : One entry per edge type or a tombstone (removed node).
    #                   ^--------^- : One entry per neighbour of 'N': its index.

    # Cached redundant information.
    n_edges::Vector{Int} # Per edge type.
    n_nodes::Vector{Int} # Per node type, not counting tombstones.

    Topology() = new([], Dict(), [], Dict(), [], Dict(), [], [], [], [], [])
end
export Topology

include("unchecked_queries.jl")
const U = Unchecked # Ease refs to unchecked queries.

include("checks.jl")
include("queries.jl")
include("display.jl")

#-------------------------------------------------------------------------------------------
# Construction primitives.

# Only push whole slices of nodes of a new type at once.
function add_nodes!(top::Topology, labels, type::Symbol)

    # Check whole transaction before commiting.
    is_node_type_valid(top, type) &&
        argerr("Node type $(repr(type)) already exists in the topology.")
    is_edge_type_valid(top, type) &&
        argerr("Node type $(repr(type)) would be confused with edge type $(repr(type)).")
    labels = check_new_nodes_labels(top, labels)

    # Add new node type.
    push!(top.node_types_labels, type)
    top.node_types_index[type] = length(top.node_types_labels)

    # Add new associated nodes.
    nindex = top.nodes_index
    nlabs = top.nodes_labels
    n_before = length(nlabs)
    for new_lab in labels
        push!(nlabs, new_lab)
        nindex[new_lab] = length(nlabs)
        for adj in (top.outgoing, top.incoming)
            # Need an entry for every edge type.
            entry = Vector{OrderedSet{Int}}()
            for _ in 1:n_edge_types(top)
                push!(entry, OrderedSet())
            end
            push!(adj, entry)
        end
    end

    # Update value.
    n_after = length(nlabs)
    push!(top.nodes_types, n_before+1:n_after)
    push!(top.n_nodes, n_after - n_before)

    top
end
export add_nodes!

function add_edge_type!(top::Topology, type::Symbol)

    # Check transaction.
    haskey(top.edge_types_index, type) &&
        argerr("Edge type $(repr(type)) already exists in the topology.")
    haskey(top.node_types_index, type) &&
        argerr("Edge type $(repr(type)) would be confused with node type $(repr(type)).")

    # Commit.
    push!(top.edge_types_labels, type)
    top.edge_types_index[type] = length(top.edge_types_labels)
    for adj in (top.outgoing, top.incoming)
        for node in adj
            node isa Tombstone && continue
            push!(node, OrderedSet{Int}())
        end
    end
    push!(top.n_edges, 0)

    top
end
export add_edge_type!

function add_edge!(top::Topology, type, source, target)
    # Check transaction.
    check_edge_type(top, type)
    check_node_ref(top, source)
    check_node_ref(top, target)
    i_type = U.edge_type_index(top, type)
    i_source = U.node_index(top, source)
    i_target = U.node_index(top, target)
    check_live_node(top, i_source, source)
    check_live_node(top, i_target, target)
    U.has_edge(top, i_type, i_source, i_target) &&
        argerr("There is already an edge of type $(repr(type)) \
                between nodes $(repr(source)) and $(repr(target)).")
    # Commit.
    _add_edge!(top, i_type, i_source, i_target)
end
function _add_edge!(top::Topology, i_type::Int, i_source::Int, i_target::Int)
    push!(top.outgoing[i_source][i_type], i_target)
    push!(top.incoming[i_target][i_type], i_source)
    top.n_edges[i_type] += 1
    top
end
export add_edge!

include("./edges_from_matrices.jl")

#-------------------------------------------------------------------------------------------
# Remove all neighbours of this node and replace it with a tombstone.

# The exposed version is checked.
function remove_node!(top::Topology, node, type)
    # Check transaction.
    check_node_ref(top, node)
    check_node_type(top, type)
    i_node = U.node_index(top, node)
    U.is_live(top, i_node) || alreadyerr(node)
    i_type = U.node_type_index(top, type)
    U.is_node_of_type(top, i_node, i_type) ||
        argerr("Node $(repr(node)) is not of type $(repr(type)).")
    _remove_node!(top, i_node, i_type)
end

# Not specifying the type requires a linear search for it.
function remove_node!(top::Topology, node)
    # Check transaction.
    check_node_ref(top, node)
    i_node = U.node_index(top, node)
    U.is_live(top, i_node) || alreadyerr(node)
    i_type = U.type_index_of_node(top, node)
    _remove_node!(top, i_node, i_type)
end

alreadyerr(node) = argerr("Node $(repr(node)) was already removed from this topology.")

export remove_node!

# Commit.
function _remove_node!(top::Topology, i_node::Int, i_type::Int)
    # Assumes the node is valid and live, and that the type does correspond.
    top.n_edges .-= length.(top.outgoing[i_node])
    top.n_edges .-= length.(top.incoming[i_node])
    ts = Tombstone()
    top.outgoing[i_node] = ts
    top.incoming[i_node] = ts
    for adjacency in (top.outgoing, top.incoming)
        for other in adjacency
            other isa Tombstone && continue
            for neighbours in other
                pop!(neighbours, i_node, nothing)
            end
        end
    end
    top.n_nodes[i_type] -= 1
    top
end

#-------------------------------------------------------------------------------------------

# Compare for equality field-by-field.
function Base.:(==)(a::Topology, b::Topology)
    for fname in fieldnames(Topology)
        fa, fb = getfield.((a, b), fname)
        fa == fb || return false
    end
    true
end

end
