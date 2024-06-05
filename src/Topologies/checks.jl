# Raise errors on invalid input, useful to check exposed queries.

#-------------------------------------------------------------------------------------------
# Check indices validity.

has_index(i, n) = 1 <= i <= n
err_index(i, n, what) = argerr("Invalid $what index ($i) \
                                when there $(n > 1 ? "are" : "is") $n $what$(s(n)).")
function check_index(i, n, what)
    has_index(i, n) || err_index(i, n, what isa String ? what : what())
    i
end

has_node_type(top::Topology, i::Int) = has_index(i, length(top.node_types_labels))
check_node_type(top::Topology, i::Int) =
    check_index(i, length(top.node_types_labels), "node type")

has_edge_type(top::Topology, i::Int) = has_index(i, length(top.edge_types_labels))
check_edge_type(top::Topology, i::Int) =
    check_index(i, length(top.edge_types_labels), "edge type")

has_node_ref(top::Topology, abs::Abs) = has_index(abs.i, length(top.nodes_labels))
check_node_ref(top::Topology, abs::Abs) =
    check_index(abs.i, length(top.nodes_labels), "node")

# Check relative indices ASSUMING the node type is valid.
has_node_ref(top::Topology, rel::Rel, type::IRef) =
    has_index(rel.i, U.n_nodes_including_removed(top, type))
check_node_ref(top::Topology, rel::Rel, type::IRef) = check_index(
    rel.i,
    U.n_nodes_including_removed(top, type),
    () -> "$(repr(U.node_type_label(top, type))) node",
)

#-------------------------------------------------------------------------------------------
# Check labels validity.

has_label(lab, set) = lab in set
function err_label(lab, set, what)
    valid = if isempty(set)
        "There are no labels yet."
    else
        "Valid labels are $(join(sort(repr.(set)), ", ", " and "))."
    end
    argerr("Invalid $what label: $(repr(lab)). $valid")
end
function check_label(lab, set, what)
    has_label(lab, set) || err_label(lab, set, what isa String ? what : what())
    lab
end

has_node_type(top::Topology, lab::Symbol) =
    has_label(lab, keys(top.node_types_index))
check_node_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.node_types_index), "node type")

has_edge_type(top::Topology, lab::Symbol) =
    has_label(lab, keys(top.edge_types_index))
check_edge_type(top::Topology, lab::Symbol) =
    check_label(lab, keys(top.edge_types_index), "edge type")

has_node_ref(top::Topology, lab::Symbol) = has_label(lab, keys(top.nodes_index))
check_node_ref(top::Topology, lab::Symbol) = check_label(lab, keys(top.nodes_index), "node")

# Check "relative labels" ASSUMING the node type is valid.
has_node_ref(top::Topology, lab::Symbol, type::IRef) =
    has_label(lab, U._node_labels(top, type))
check_node_ref(top::Topology, lab::Symbol, type::IRef) = check_label(
    lab,
    U._nodes_labels(top, type),
    () -> "$(repr(U.node_type_label(top, type))) node",
)

#-------------------------------------------------------------------------------------------
# Check node liveliness, assuming the reference is valid.
function check_live_node(top::Topology, node::AbsRef, original_ref::AbsRef = node)
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
        if has_node_ref(top, new_lab)
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
