# Raise errors on invalid input, useful to check exposed queries.

# Check indices validity.
function check_index(i, n, what)
    1 <= i <= n || argerr("Invalid $what index ($i) \
                           when there $(n > 1 ? "are" : "is") $n $what$(s(n)).")
    i
end
function check_node_type(top::Topology, i::Int)
    check_index(i, length(top.node_types_labels), "node type")
end
function check_edge_type(top::Topology, i::Int)
    check_index(i, length(top.edge_types_labels), "edge type")
end
check_node_ref(top::Topology, i::Int) = check_index(i, length(top.nodes_labels), "node")

# Check labels validity.
function check_label(lab, set, what)
    lab in set || argerr("Invalid $what label: $(repr(lab)). \
                         Valid labels are $(join(set, ", ", " and ")).")
    lab
end
check_node_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.node_types_index), "node type")
check_edge_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.edge_types_index), "edge type")
check_node_ref(top::Topology, lab::Symbol) = check_label(lab, keys(top.nodes_index), "node")

# Check node liveliness, assuming the reference is valid.
function check_live_node(top::Topology, node, original_ref = node)
    # (use the original reference to trace back to actual user input
    # and improve error message)
    U.is_removed(top, node) &&
        argerr("Node $(repr(original_ref)) has been removed from this topology.")
    node
end
