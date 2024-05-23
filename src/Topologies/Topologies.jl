module Topologies

using OrderedCollections

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
    node_types_labels::Vector{Symbol} # [type index: type label]
    node_types_index::Dict{Symbol,Int} # {type label: type index}
    edge_types_labels::Vector{Symbol}
    edge_types_index::Dict{Symbol,Int}
    # List nodes and their associated types.
    # Nodes are *sorted by type*:
    # so that all nodes with the same type are stored contiguously in this array.
    nodes_labels::Vector{Symbol} # [node index: node label]
    nodes_index::Dict{Symbol,Int} # {node label: node index}
    nodes_types::Vector{UnitRange{Int}} # [type index: (start, end) of nodes with this type]
    # Topological information: paired, layered adjacency lists.
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
    haskey(top.node_types_index, type) &&
        argerr("Node type $(repr(type)) has already been pushed.")
    haskey(top.edge_types_index, type) &&
        argerr("Node type $(repr(type)) could be confused with edge type $(repr(type)).")
    push!(top.node_types_labels, type)
    top.node_types_index[type] = length(top.node_types_labels)
    nlabs = top.nodes_labels
    nindex = top.nodes_index
    n_before = length(nlabs)
    for new_lab::Symbol in labels
        haskey(nindex, new_lab) && argerr("Label :$new_lab was already given \
                                           to a node of type \
                                           $(repr(node_type(top, new_lab))).")
        push!(nlabs, new_lab)
        nindex[new_lab] = length(nlabs)
        for adj in (top.outgoing, top.incoming)
            push!(adj, Vector{OrderedSet{Int}}())
        end
    end
    n_after = length(nlabs)
    push!(top.nodes_types, n_before+1:n_after)
    push!(top.n_nodes, n_after - n_before)
    top
end
export add_nodes!

function add_edge_type!(top::Topology, type::Symbol)
    haskey(top.edge_types_index, type) &&
        argerr("Edge type $(repr(type)) has already been added.")
    haskey(top.node_types_index, type) &&
        argerr("Edge type $(repr(type)) would be confused with node type $(repr(type)).")
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
    check_edge_type(top, type)
    check_node_ref(top, source)
    check_node_ref(top, target)
    i_type = U.edge_type_index(top, type)
    i_source = U.node_index(top, source)
    i_target = U.node_index(top, target)
    check_live_node(top, i_source)
    check_live_node(top, i_target)
    U.has_edge(top, i_type, i_source, i_target) &&
        argerr("There is already an edge of type $(repr(type))
                betwen nodes $(repr(source)) and $(repr(target)).")
    push!(top.outgoing[i_source][i_type], i_target)
    push!(top.incoming[i_target][i_type], i_source)
    top.n_edges[i_type] += 1
    top
end
export add_edge!

end
