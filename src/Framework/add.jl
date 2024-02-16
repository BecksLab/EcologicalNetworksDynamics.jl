# Add components to the system: check and expand.

# Prepare thorough analysis of recursive sub-blueprints possibly brought
# by the blueprints given.
# Reify the underlying 'forest' structure.
struct Node
    blueprint::Blueprint
    parent::Option{Node} # None if root.
    implied::Bool # Raise if 'implied' by the parent and not 'embedded'.
    children::Vector{Node}
end

# Bundle information necessary for abortion on failure
# and displaying of a useful message,
# provided the tree will still be consistenly readable.
struct EmbeddedAlreadyInValue
    node::Node
end
struct InconsistentForSameComponent
    focal::Node
    other::Node
end
struct MissingRequiredComponent
    node::Node
    reason::Reason
    for_expansion::Bool # Raise if the blueprint requires, lower if the component requires.
end
struct ConflictWithSystemComponent
    node::Node
    other::CompType
    reason::Reason
end
struct ConflictWithBroughtComponent
    node::Node
    other::Node
    reason::Reason
end
struct HookCheckFailure
    node::Node
    message::String
end
struct UnexpectedHookFailure
    node::Node
    exception::Any
    late::Bool
end
struct ExpansionAborted
    node::Node
    exception::Any
end

# Keep track of all blueprints about broughts,
# indexed by their concrete component instance.
const Brought = Dict{Component,Vector{Node}}

#-------------------------------------------------------------------------------------------
# Recursively create during first pass, pre-order,
# possibly checking the indexed list of nodes already brought.
function Node(
    bp::Blueprint,
    parent::Option{Node},
    implied::Bool,
    system::System,
    brought::Brought,
)

    # Get our owned local copy so it cannot be changed afterwards.
    blueprint = copy(bp)
    component = componentof(blueprint)

    # Create node and connect to parent, without its children yet.
    node = Node(blueprint, parent, implied, [])

    # Check for duplication if embedded.
    !implied && has_component(system, component) && throw(EmbeddedAlreadyInValue(node))

    # Check for consistency with other possible blueprints bringing the same component.
    if haskey(brought, component)
        others = brought[component]
        for other in others
            blueprint == other.blueprint || throw(InconsistentForSameComponent(node, other))
        end
        push!(others, node)
    else
        brought[component] = [node]
    end

    # Recursively construct children.
    for I in implies(blueprint)
        implied_component = componentof(I)
        has_concrete_component(system, implied_component) && continue
        implied_bp = construct_implied(I, blueprint)
        child = Node(implied_bp, node, true, system, brought)
        push!(node.children, child)
    end
    for E in embeds(blueprint)
        embedded_bp = construct_embedded(E, blueprint)
        child = Node(embedded_bp, node, false, system, brought)
        push!(node.children, child)
    end

    node
end

#-------------------------------------------------------------------------------------------
# Recursively check during second pass, post-order,
# assuming the whole tree is set up.
function check(node::Node, system::System, brought::Brought, checked::OrderedSet{Component})

    # Recursively check children first.
    for child in node.children
        check(child, brought, checked)
    end

    # Check requirements.
    blueprint = node.blueprint
    component = componentof(blueprint)
    for (reqs, for_expansion) in
        [(requires(component), false), (expands_from(blueprint), true)]
        for (R, reason) in reqs
            # Check against the current system value.
            has_component(system, R) && continue
            # Check against other components about to be brought.
            any(checked) do c
                R <: typeof(c)
            end || throw(MissingRequiredComponent(node, reason, for_expansion))
        end
    end

    # Guard against conflicts.
    for (C, reason) in conflicts(component)
        has_component(system, C) && throw(ConflictWithSystemComponent(node, C, reason))
        for c in checked
            C <: typeof(c)
            throw(ConflictWithBroughtComponent(node, brought[c], reason))
        end
    end

    # Run exposed hook for further checking.
    try
        early_check(blueprint)
    catch e
        if e isa BlueprintCheckFailure
            throw(HookCheckFailure(node, e.message))
        else
            throw(UnexpectedHookFailure(node, e, false))
        end
    end

end

# ==========================================================================================
# The actual implementation.
function add!(system::System{V}, blueprints::Blueprint{V}...) where {V}

    if length(blueprints) == 0
        argerr("No blueprint given to expand into the system.")
    end

    forest = []
    brought = Dict() # Populated during pre-order traversal.
    checked = OrderedSet() # Populated during first post-order traversal.

    try
        #---------------------------------------------------------------------------------------
        # Read-only preliminary checking.

        try

            # Preorder visit: construct the trees.
            for bp in blueprints
                root = Node(bp, nothing, false, system, brought)
                push!(forest, root)
            end

            # Post-order visit, check requirements.
            for node in forest
                check(node, system, brought, checked)
            end

        catch e
            # The system value has not been modified during if the error is caught now.
            if e isa EmbeddedAlreadyInValue
                throw("Unimplemented: construct error message from $e.")
            elseif e isa InconsistentForSameComponent
                throw("Unimplemented: construct error message from $e.")
            elseif e isa MissingRequiredComponent
                throw("Unimplemented: construct error message from $e.")
            elseif e isa ConflictWithSystemComponent
                throw("Unimplemented: construct error message from $e.")
            elseif e isa ConflictWithBroughtComponent
                throw("Unimplemented: construct error message from $e.")
            elseif e isa HookCheckFailure
                # This originated from hook in early_check.
                throw("Unimplemented: construct error message from $e.")
            else
                rethrow(e)
            end
        end

        #---------------------------------------------------------------------------------------
        # Secondary checking, occuring while the system is being modified.

        try

            # Second post-order visit: expand the blueprints.
            for c in checked
                node = first(brought[c])
                blueprint = node.blueprint
                # Last check hook against current system value.
                try
                    late_check(system._value, blueprint)
                catch e
                    if e isa BlueprintCheckFailure
                        throw(HookCheckFailure(node, e.message, true))
                    else
                        throw(UnexpectedHookFailure(node, e, true))
                    end
                end
                try
                    expand!(system._value, blueprint, system)
                catch e
                    throw(ExpansionAborted(node, e))
                end
            end

        catch e
            # At this point, the system *has been modified*
            # but we cannot guarantee that all desired blueprints
            # have been expanded as expected.
            if e isa HookCheckFailure
                # This originated from hook in late check:
                # not all blueprints have been expanded,
                # but the underlying system state consistency is safe.
                throw("Unimplemented: construct error message from $e.")
            elseif e isa ExpansionAborted
                # This is unexpected and it may have occured during expansion.
                # The underlying system state consistency is no longuer guaranteed.
                this =
                    length(blueprints) > 1 ?
                    "blueprints $(join(map(typeof, blueprints), ", ", " and "))" :
                    "blueprint $(blueprints[1])"
                syserr(
                    V,
                    "\n$(crayon"red")\
                     ⚠ ⚠ ⚠ Failure during expansion of $this. ⚠ ⚠ ⚠\
                     $(crayon"reset")\n\
                     This system state consistency is no longer guaranteed by the program. \
                     This should not happen and must be considered a bug \
                     within the components library. \
                     Consider reporting if you can reproduce with a minimal working example. \
                     In any case, please drop the current system value and create a new one.",
                )
            else
                rethrow(e)
            end
        end
    catch e
        if e isa UnexpectedHookFailure
            # If 'late' is raised,
            # warn that some blueprints may have been expanded but not the others.
            throw("Unimplemented: construct error message from $e.")
            @error "\n$(crayon"red")\
                    ⚠ Unexpected failure while checking $this \
                    for expansion into system for '$V'. ⚠\
                    $(crayon"reset")\n\
                    This is either a bug in the framework or in the components library. \
                    Consider reporting if you can reproduce with a minimal working example."
        else
        end
    end

    system

end
