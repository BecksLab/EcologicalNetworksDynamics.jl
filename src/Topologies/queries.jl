# Build over the Unchecked module and checking functions
# to expose checked queries.

const imap = Iterators.map
idmap(x) = imap(identity, x) # Useful to not leak refs to private collections.

# Information about types.
n_node_types(top::Topology) = length(top.node_types_labels)
n_edge_types(top::Topology) = length(top.edge_types_labels)
_node_types(top::Topology) = top.node_types_labels
node_types(top::Topology) = idmap(_node_types(top))
_edge_types(top::Topology) = top.edge_types_labels
edge_types(top::Topology) = idmap(_edge_types(top))
