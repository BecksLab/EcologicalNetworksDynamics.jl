# Basic queries all assume that input references are valid.
# Namespace them all under this module as they share this property.
# Methods that would leak references are protected with a '_' prefix.
module Unchecked

import ..Topologies: Topology, Tombstone, Abs, Rel, AbsRef, IRef

const imap = Iterators.map
const ifilter = Iterators.filter
idmap(x) = imap(identity, x) # Useful to not leak refs to private collections.

# ==========================================================================================
# Types.

node_type_label(top::Topology, i::Int) = top.node_types_labels[i]
node_type_index(top::Topology, lab::Symbol) = top.node_types_index[lab]
node_type_label(::Topology, lab::Symbol) = lab
node_type_index(::Topology, i::Int) = i
edge_type_label(top::Topology, i::Int) = top.edge_types_labels[i]
edge_type_index(top::Topology, lab::Symbol) = top.edge_types_index[lab]
edge_type_label(::Topology, lab::Symbol) = lab
edge_type_index(::Topology, i::Int) = i

# ==========================================================================================
# Nodes.

# General information.
n_nodes(top::Topology, type::IRef) = top.n_nodes[node_type_index(top, type)]
n_nodes_including_removed(top::Topology, type::IRef) =
    length(top.nodes_types[node_type_index(top, type)])
_nodes_abs_range(top::Topology, type::IRef) =  # Okay to leak (immutable) but not abs-wrapped..
    top.nodes_types[node_type_index(top, type)]
nodes_abs_indices(top::Topology, type::IRef) =
    imap(Abs, top.nodes_types[node_type_index(top, type)])
_nodes_labels(top::Topology, type::IRef) = top.nodes_labels[_nodes_abs_range(top, type)]
node_labels(top::Topology, type::IRef) = idmap(_nodes_labels(top, type))

# Particular information about nodes.
node_label(top::Topology, abs::Abs) = top.nodes_labels[abs.i]
node_abs_index(top::Topology, label::Symbol) = Abs(top.nodes_index[label])
node_label(::Topology, lab::Symbol) = lab
node_abs_index(::Topology, abs::Abs) = abs
# Append correct offset to convert between relative / absolute indices.
first_node_abs_index(top::Topology, type::IRef) = first(nodes_abs_indices(top, type))
node_index_offset(top::Topology, type::IRef) = first_node_abs_index(top, type).i - 1
node_abs_index(top::Topology, relative_index::Rel, type::IRef) =
    Abs(relative_index.i + node_index_offset(top, type))
node_rel_index(top::Topology, node::AbsRef, type::IRef) =
    Rel(node_abs_index(top, node).i - node_index_offset(top, type))
# For consistency with the above, node type information is ignored when unnecessary
# because we ASSUME here that it has already been checked for consistency.
node_abs_index(top::Topology, lab::AbsRef, ::IRef) = node_abs_index(top, lab)

# Querying node type requires a linear search,
# but it is generally assumed that if you know the node, then you already know its type.
type_index_of_node(top::Topology, node::AbsRef) =
    findfirst(range -> node_abs_index(top, node).i in range, top.nodes_types)
type_of_node(top::Topology, node::AbsRef) =
    node_type_label(top, type_index_of_node(top, node))
# But it is O(1) to check whether a given node is of the given type.
function is_node_of_type(top::Topology, node::AbsRef, type::IRef)
    i_type = node_type_index(top, type)
    i_node = node_abs_index(top, node)
    i_node.i in top.nodes_types[i_type]
end

is_removed(top::Topology, node::AbsRef) =
    top.outgoing[node_abs_index(top, node).i] isa Tombstone
is_live(top::Topology, node::AbsRef) = !is_removed(top, node)

# ==========================================================================================
# Edges.

n_edges(top::Topology, type) = top.n_edges[edge_type_index(top, type)]

# Direct neighbourhood when querying particular edge type.
# (assuming focal node is not a tombstone)
function _outgoing_indices(top::Topology, node::AbsRef, edge_type::IRef)
    i_type = edge_type_index(top, edge_type)
    _outgoing_indices(top, node)[i_type]
end
function _incoming_indices(top::Topology, node::AbsRef, edge_type::IRef)
    i_type = edge_type_index(top, edge_type)
    _incoming_indices(top, node)[i_type]
end
outgoing_indices(top::Topology, node::AbsRef, type::IRef) =
    imap(Abs, _outgoing_indices(top, node, type))
incoming_indices(top::Topology, node::AbsRef, type::IRef) =
    imap(Abs, _incoming_indices(top, node, type))
outgoing_labels(top::Topology, node::AbsRef, type::IRef) =
    imap(i -> top.nodes_labels[i], _outgoing_indices(top, node, type))
incoming_labels(top::Topology, node, type::IRef) =
    imap(i -> top.nodes_labels[i], _incoming_indices(top, node, type))

# Direct neighbourhood: return twolevel slices:
# first a slice over edge types, then nested neighbours with this edge type.
# (assuming focal node is not a tombstone)
function _outgoing_indices(top::Topology, node::AbsRef)
    i_node = node_abs_index(top, node)
    top.outgoing[i_node.i]
end
function _incoming_indices(top::Topology, node::AbsRef)
    i_node = node_abs_index(top, node)
    top.incoming[i_node.i]
end
outgoing_indices(top::Topology, node::AbsRef) =
    imap(enumerate(_outgoing_indices(top, node))) do (i_edge_type, _neighbours)
        (i_edge_type, imap(Abs, _neighbours))
    end
incoming_indices(top::Topology, node::AbsRef) =
    imap(enumerate(_incoming_indices(top, node))) do (i_edge_type, _neighbours)
        (i_edge_type, imap(Abs, _neighbours))
    end
outgoing_labels(top::Topology, node::AbsRef) =
    imap(enumerate(_outgoing_indices(top, node))) do (i_edge, _neighbours)
        (
            top.edge_types_labels[i_edge],
            imap(i_node -> top.nodes_labels[i_node], _neighbours),
        )
    end
incoming_labels(top::Topology, node::AbsRef) =
    imap(enumerate(_incoming_indices(top, node))) do (i_edge, _neighbours)
        (
            top.edge_types_labels[i_edge],
            imap(i_node -> top.nodes_labels[i_node], _neighbours),
        )
    end


# Filter adjacency iterators given one particular edge type.
# Also return twolevel iterators: focal node, then its neighbours.
function _outgoing_edges_indices(top::Topology, edge_type::IRef)
    i_type = edge_type_index(top, edge_type)
    imap(ifilter(enumerate(top.outgoing)) do (_, node)
        !(node isa Tombstone)
    end) do (i, _neighbours)
        (i, _neighbours[i_type])
    end
end
function _incoming_edges_indices(top::Topology, edge_type::IRef)
    i_type = edge_type_index(top, edge_type)
    imap(ifilter(enumerate(top.incoming)) do (_, node)
        !(node isa Tombstone)
    end) do (i, _neighbours)
        (i, _neighbours[i_type])
    end
end
outgoing_edges_indices(top::Topology, edge_type::IRef) =
    imap(_outgoing_edges_indices(top, edge_type)) do (i_node, _neighbours)
        (Abs(i_node), imap(Abs, _neighbours))
    end
incoming_edges_indices(top::Topology, edge_type::IRef) =
    imap(_incoming_edges_indices(top, edge_type)) do (i_node, _neighbours)
        (Abs(i_node), imap(Abs, _neighbours))
    end
outgoing_edges_labels(top::Topology, edge_type::IRef) =
    imap(_outgoing_edges_indices(top, edge_type)) do (i_node, _neighbours)
        (node_label(top, i_node), imap(i -> node_label(top, i), _neighbours))
    end
incoming_edges_labels(top::Topology, edge_type::IRef) =
    imap(_incoming_edges_indices(top, edge_type)) do (i_node, _neighbours)
        (node_label(top, i_node), imap(i -> node_label(top, i), _neighbours))
    end

# Same, but filters for one particular node type.
function outgoing_edges_indices(top::Topology, edge_type::IRef, node_type::IRef)
    i_et = edge_type_index(top, edge_type)
    range = _nodes_abs_range(top, node_type)
    imap(ifilter(zip(range, top.outgoing[range])) do (_, node)
        !(node isa Tombstone)
    end) do (i_node, _neighbours)
        (Abs(i_node), imap(Abs, ifilter(in(range), _neighbours[i_et])))
    end
end
function incoming_edges_indices(top::Topology, edge_type::IRef, node_type::IRef)
    i_et = edge_type_index(top, edge_type)
    range = _nodes_abs_range(top, node_type)
    imap(ifilter(zip(range, top.incoming[range])) do (_, node)
        !(node isa Tombstone)
    end) do (i_node, _neighbours)
        (Abs(i_node), imap(Abs, ifilter(in(range), _neighbours[i_et])))
    end
end
outgoing_edges_labels(top::Topology, edge_type::IRef, node_type::IRef) =
    imap(outgoing_edges_indices(top, edge_type, node_type)) do (i_node, neighbours)
        (node_label(top, i_node), imap(i -> node_label(top, i), neighbours))
    end
incoming_edges_labels(top::Topology, edge_type::IRef, node_type::IRef) =
    imap(incoming_edges_indices(top, edge_type, node_type)) do (i_node, neighbours)
        (node_label(top, i_node), imap(i -> node_label(top, i), neighbours))
    end

function has_edge(top::Topology, type, source::AbsRef, target::AbsRef)
    type = edge_type_index(top, type)
    source = node_abs_index(top, source)
    target = node_abs_index(top, target)
    target.i in top.outgoing[source.i][type]
end

end
