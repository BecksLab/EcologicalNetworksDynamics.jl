# Raise errors on invalid input, useful to check exposed queries.

#-------------------------------------------------------------------------------------------
# Check indices validity.

is_index_valid(i, n) = 1 <= i <= n
err_index(i, n, what) = argerr("Invalid $what index ($i) \
                                when there $(n > 1 ? "are" : "is") $n $what$(s(n)).")
function check_index(i, n, what)
    is_index_valid(i, n) || err_index(i, n, what)
    i
end

is_node_type_valid(top::Topology, i::Int) = is_index_valid(i, length(top.node_types_labels))
check_node_type(top::Topology, i::Int) =
    check_index(i, length(top.node_types_labels), "node type")

is_edge_type_valid(top::Topology, i::Int) = is_index_valid(i, length(top.edge_types_labels))
check_edge_type(top::Topology, i::Int) =
    check_index(i, length(top.edge_types_labels), "edge type")

is_node_ref_valid(top::Topology, i::Int) = is_index_valid(i, length(top.nodes_labels))
check_node_ref(top::Topology, i::Int) = check_index(i, length(top.nodes_labels), "node")

#-------------------------------------------------------------------------------------------
# Check labels validity.

is_label_valid(lab, set) = lab in set
function err_label(lab, set, what)
    valid = if isempty(set)
        "There are no labels yet."
    else
        "Valid labels are $(join(sort(repr.(set)), ", ", " and "))."
    end
    argerr("Invalid $what label: $(repr(lab)). $valid")
end
function check_label(lab, set, what)
    is_label_valid(lab, set) || err_label(lab, set, what)
    lab
end

is_node_type_valid(top::Topology, lab::Symbol) =
    is_label_valid(lab, keys(top.node_types_index))
check_node_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.node_types_index), "node type")

is_edge_type_valid(top::Topology, lab::Symbol) =
    is_label_valid(lab, keys(top.edge_types_index))
check_edge_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.edge_types_index), "edge type")

is_node_ref_valid(top::Topology, lab::Symbol) = is_label_valid(lab, keys(top.nodes_index))
check_node_ref(top::Topology, lab::Symbol) = check_label(lab, keys(top.nodes_index), "node")

#-------------------------------------------------------------------------------------------
# Check node liveliness, assuming the reference is valid.
function check_live_node(top::Topology, node, original_ref = node)
    # (use the original reference to trace back to actual user input
    # and improve error message)
    U.is_removed(top, node) &&
        argerr("Node $(repr(original_ref)) has been removed from this topology.")
    node
end

#-------------------------------------------------------------------------------------------
# Check node labels availability.
function check_new_nodes_labels(top::Topology, labels::Vector{Symbol})
    for new_lab in labels
        if is_node_ref_valid(top, new_lab)
            argerr("Label :$new_lab was already given \
                    to a node of type \
                    $(repr(U.type_of_node(top, new_lab))).")
        end
    end
    labels
end
function check_new_nodes_labels(top::Topology, labels)
    try
        labels = Symbol[Symbol(l) for l in labels]
    catch
        argerr("The labels provided cannot be iterated into a collection of symbols. \
                Received: $(repr(labels)).")
    end
    check_new_nodes_labels(top, labels)
end
