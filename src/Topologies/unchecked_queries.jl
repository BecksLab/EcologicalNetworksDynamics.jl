# Basic queries,
# all assume that input references are valid.
# Methods that would leak references are protected with a '_' prefix.

const imap = Iterators.map
const ifilter = Iterators.filter
idmap(x) = imap(identity, x) # Useful to not leak refs to private collections.

# Information about types.
n_node_types(top::Topology) = length(top.node_types_labels)
n_edge_types(top::Topology) = length(top.edge_types_labels)
node_type_label(top::Topology, i::Int) = top.node_types_labels[i]
node_type_index(top::Topology, lab::Symbol) = top.node_types_index[lab]
node_type_label(::Topology, lab::Symbol) = lab
node_type_index(::Topology, i::Int) = i
edge_type_label(top::Topology, i::Int) = top.edge_types_labels[i]
edge_type_index(top::Topology, lab::Symbol) = top.edge_types_index[lab]
edge_type_label(::Topology, lab::Symbol) = lab
edge_type_index(::Topology, i::Int) = i
_node_types(top::Topology) = top.node_types_labels
node_types(top::Topology) = idmap(_node_types(top))
_edge_types(top::Topology) = top.edge_types_labels
edge_types(top::Topology) = idmap(_edge_types(top))

# General information about nodes.
n_nodes(top::Topology, type) = top.n_nodes[node_type_index(top, type)]
n_nodes_including_removed(top::Topology, type) =
    length(top.nodes_types[node_type_index(top, type)])
nodes_indices(top::Topology, type) = # Okay to leak: immutable.
    top.nodes_types[node_type_index(top, type)]
_nodes_labels(top::Topology, type) = top.nodes_labels[nodes_indices(top, type)]
node_labels(top::Topology, type) = idmap(_nodes_labels(top, type))

# Particular information about nodes.
node_label(top::Topology, i::Int) = top.nodes_labels[i]
node_index(top::Topology, label::Symbol) = top.nodes_index[label]
node_label(::Topology, lab::Symbol) = lab
node_index(::Topology, i::Int) = i
# Querying node type requires a linear search,
# but it is generally assumed that if you know the node, then you already know its type.
node_type_index(top::Topology, id) =
    findfirst(range -> node_index(top, id) in range, top.nodes_types)
node_type(top::Topology, id) = node_type_label(node_type_index(top, id))

is_removed(top::Topology, node) = top.outgoing[node_index(top, node)] isa Tombstone
is_live(top::Topology, node) = !is_removed(top, node)

# Information about edges.
n_edges(top::Topology, type) = top.n_edges[edge_type_index(top, type)]

# Direct neighbourhood when querying particular edge type.
# (assuming focal node is not a tombstone)
function _outgoing_indices(top::Topology, node, edge_type)
    i_type = edge_type_index(top, edge_type)
    _outgoing_indices(top, node)[i_type]
end
function _incoming_indices(top::Topology, node, edge_type)
    i_type = edge_type_index(top, edge_type)
    _incoming_indices(top, node)[i_type]
end
outgoing_indices(top::Topology, node, type) = idmap(_outgoing_indices(top, node, type))
incoming_indices(top::Topology, node, type) = idmap(_incoming_indices(top, node, type))
outgoing_labels(top::Topology, node, type) =
    imap(i -> top.nodes_labels[i], _outgoing_indices(top, node, type))
incoming_labels(top::Topology, node, type) =
    imap(i -> top.nodes_labels[i], _incoming_indices(top, node, type))

# Direct neighbourhood: return twolevel slices:
# first a slice over edge types, then nested neighbours with this edge type.
# (assuming focal node is not a tombstone)
function _outgoing_indices(top::Topology, node)
    i_node = node_index(top, node)
    top.outgoing[i_node]
end
function _incoming_indices(top::Topology, node)
    i_node = node_index(top, node)
    top.incoming[i_node]
end
outgoing_indices(top::Topology, node) = imap(
    (i_edge_type, _neighbours) -> (i_edge_type, idmap(_neighbours)),
    enumerate(_outgoing_indices(top, node)),
)
incoming_indices(top::Topology, node) = imap(
    (i_edge_type, _neighbours) -> (i_edge_type, idmap(_neighbours)),
    enumerate(_incoming_indices(top, node)),
)
outgoing_labels(top::Topology, node) = imap(
    (i_edge, _neighbours) -> (
        top.edge_types_labels[i_edge],
        imap(i_node -> top.nodes_labels[i_node], _neighbours),
    ),
    enumerate(_outgoing_indices(top, node)),
)
incoming_labels(top::Topology, node) = imap(
    (i_edge, _neighbours) -> (
        top.edge_types_labels[i_edge],
        imap(i_node -> top.nodes_labels[i_node], _neighbours),
    ),
    enumerate(_incoming_indices(top, node)),
)

# Filter adjacency iterators given one particular edge type.
# Also return twolevel iterators: focal node, then its neighbours.
function _outgoing_edges_indices(top::Topology, edge_type)
    i_type = edge_type_index(top, edge_type)
    imap(ifilter(enumerate(top.outgoing)) do (_, node)
        !(node isa Tombstone)
    end) do (i, _neighbours)
        (i, _neighbours[i_type])
    end
end
function _incoming_edges_indices(top::Topology, edge_type)
    i_type = edge_type_index(top, edge_type)
    imap(ifilter(enumerate(top.incoming)) do (_, node)
        !(node isa Tombstone)
    end) do (i, _neighbours)
        (i, _neighbours[i_type])
    end
end
outgoing_edges_indices(top::Topology, edge_type) = imap(
    (i_node, _neighbours) -> (i_node, idmap(_neighbours)),
    _outgoing_edges_indices(top, edge_type),
)
incoming_edges_indices(top::Topology, edge_type) = imap(
    (i_node, _neighbours) -> (i_node, idmap(_neighbours)),
    _incoming_edges_indices(top, edge_type),
)
outgoing_edges_labels(top::Topology, edge_type) = imap(
    (i_node, _neighbours) ->
        (node_label(top, i_node), idmap(i -> node_label(top, i), _neighbours)),
    _outgoing_edges_indices(top, edge_type),
)
incoming_edges_labels(top::Topology, edge_type) = imap(
    (i_node, _neighbours) ->
        (node_label(top, i_node), idmap(i -> node_label(top, i), _neighbours)),
    _incoming_edges_indices(top, edge_type),
)

function has_edge(top::Topology, type, source, target)
    type = edge_type_index(top, type)
    source = node_index(top, source)
    target = node_index(top, target)
    target in top.outgoing[source][type]
end
