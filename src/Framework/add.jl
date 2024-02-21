# Add components to the system: check and expand.

# Prepare thorough analysis of recursive sub-blueprints possibly brought
# by the blueprints given.
# Reify the underlying 'forest' structure.
struct Node
    blueprint::Blueprint
    parent::Option{Node}
    implied::Bool # Raise if 'implied' by the parent and not 'embedded'.
    children::Vector{Node}
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
    !implied && has_component(system, component) && throw(BroughtAlreadyInValue(node))

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
        can_imply(blueprint, I) || continue
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
        check(child, system, brought, checked)
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
            end || throw(MissingRequiredComponent(node, R, reason, for_expansion))
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
            rethrow(HookCheckFailure(node, e.message, false))
        else
            throw(UnexpectedHookFailure(node, false))
        end
    end

    push!(checked, component)

end

# ==========================================================================================
# The actual implementation.
function add!(system::System{V}, blueprints::Blueprint{V}...) where {V}

    if length(blueprints) == 0
        argerr("No blueprint given to expand into the system.")
    end

    forest = Node[]
    brought = Brought() # Populated during pre-order traversal.
    checked = OrderedSet{Component}() # Populated during first post-order traversal.

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
        E = typeof(e)
        if E in (
            BroughtAlreadyInValue,
            InconsistentForSameComponent,
            MissingRequiredComponent,
            ConflictWithSystemComponent,
            ConflictWithBroughtComponent,
            HookCheckFailure,
        )
            rethrow(AddError(V, e))
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

            # Temporary patch after renaming check -> late_check
            # to forbid silent no-checks.
            applicable(check, system_value_type, blueprint) &&
                throw("The `check` method seems defined for $blueprint, \
                       but it wouldn't be run as the new name is `late_check`.")

            # Last check hook against current system value.
            try
                late_check(system._value, blueprint)
            catch e
                if e isa BlueprintCheckFailure
                    rethrow(HookCheckFailure(node, e.message, true))
                else
                    throw(UnexpectedHookFailure(node, true))
                end
            end

            # Record.
            component = componentof(blueprint)
            C = typeof(component)
            crt, abs = system._concrete, system._abstract
            crt[C] = component
            for sup in supertypes(C)
                sup === C && continue
                sup === Component{V} && break
                sub = haskey(abs, sup) ? abs[sup] : (abs[sup] = Set{CompType{V}}())
                push!(sub, C)
            end

            # Expand.
            try
                expand!(system._value, blueprint, system)
            catch _
                throw(ExpansionAborted(node))
            end

        end

    catch e
        # At this point, the system *has been modified*
        # but we cannot guarantee that all desired blueprints
        # have been expanded as expected.
        E = typeof(e)
        if E in (HookCheckFailure, UnexpectedHookFailure)
            # This originated from hook in late check:
            # not all blueprints have been expanded,
            # but the underlying system state consistency is safe.
            rethrow(AddError(V, e))
        else
            # This is unexpected and it may have occured during expansion.
            # The underlying system state consistency is no longuer guaranteed.
            if e isa ExpansionAborted
                title = "Failure during blueprint expansion."
                subtitle = "This is a bug in the components library."
                epilog = render_path(e.node)
            else
                title = "Failure during blueprint addition."
                subtitle = "This is a bug in the internal addition procedure.\n"
                epilog = ""
            end
            throw(ErrorException("\n$(crayon"red")\
                   ⚠ ⚠ ⚠ $title ⚠ ⚠ ⚠\
                   $(crayon"reset")\n\
                   $subtitle\
                   This system state consistency \
                   is no longer guaranteed by the program. \
                   This should not happen and must be considered a bug \
                   within the components library. \
                   Consider reporting if you can reproduce \
                   with a minimal working example. \
                   In any case, please drop the current system value \
                   and create a new one.\n\
                   $epilog"))
        end
    end

    system

end
export add!

# ==========================================================================================
# Dedicated exceptions.
# Bundle information necessary for abortion on failure
# and displaying of a useful message,
# provided the tree will still be consistenly readable.

abstract type AddException <: SystemException end

struct BroughtAlreadyInValue <: AddException
    node::Node
end

struct InconsistentForSameComponent <: AddException
    focal::Node
    other::Node
end

struct MissingRequiredComponent <: AddException
    node::Node
    miss::CompType
    reason::Reason
    for_expansion::Bool # Raise if the blueprint requires, lower if the component requires.
end

struct ConflictWithSystemComponent <: AddException
    node::Node
    other::CompType
    reason::Reason
end

struct ConflictWithBroughtComponent <: AddException
    node::Node
    other::Node
    reason::Reason
end

struct HookCheckFailure <: AddException
    node::Node
    message::String
    late::Bool
end

struct UnexpectedHookFailure <: AddException
    node::Node
    late::Bool
end

struct ExpansionAborted <: AddException
    node::Node
end

# Once the above have been processed,
# convert into this dedicated user-facing one:
struct AddError{V} <: SystemException
    e::AddException
    _::PhantomData{V}
    AddError(::Type{V}, e) where {V} = new{V}(e, PhantomData{V}())
end
Base.showerror(io::IO, e::AddError{V}) where {V} = showerror(io, e.e)

# ==========================================================================================
# Ease exception testing by comparing blueprint paths along tree to simple vectors.
# The vector starts from current node,
# and expands up to a sequence of blueprint types and flags:
#   true: implied
#   false: embedded
const PathElement = Union{Bool,Type{<:Blueprint}}
const BpPath = Vector{PathElement}

# Extract path from Node.
function path(node::Node)::BpPath
    res = PathElement[typeof(node.blueprint)]
    while !isnothing(node.parent)
        push!(res, node.implied)
        node = node.parent
        push!(res, typeof(node.blueprint))
    end
    res
end

# ==========================================================================================
# Render errors into proper error messages.

function render_path(path::BpPath)
    gray = crayon"black"
    blue = crayon"blue"
    reset = crayon"reset"
    res = "$(gray)in$reset $blue$(path[1])$reset\n"
    i = 2
    while i <= length(path)
        broughtby = path[i] ? "     implied by:" : "embedded within:"
        parent = path[i+1]
        res *= "$gray$broughtby$reset $blue$parent$reset\n"
        i += 2
    end
    res
end
render_path(node::Node) = render_path(path(node))

function Base.showerror(io::IO, e::BroughtAlreadyInValue)
    (; node, reason, for_expansion) = e
    path = render_path(node)
    comp = componentof(node.blueprint)
    print(
        io,
        "Blueprint expands into component '$comp', \
         which is already in the system.\n$path",
    )
end

function Base.showerror(io::IO, e::MissingRequiredComponent)
    (; node, miss, reason, for_expansion) = e
    path = render_path(node)
    comp = componentof(node.blueprint)
    if for_expansion
        header = "Blueprint cannot expand without component $miss"
    else
        header = "Component $comp requires $miss, not found in the system"
    end
    if isnothing(reason)
        body = "."
    else
        body = ":\n  $reason"
    end
    print(io, "$header$body\n$path")
end

late_fail_warn(path) = "$(crayon"red")\
                        Not all blueprints have been expanded.\
                        $(crayon"reset")\n\
                        The system consistency is still guaranteed, \
                        but some components have not been added to it.\n\
                        $path"

function Base.showerror(io::IO, e::HookCheckFailure)
    (; node, message, late) = e
    path = render_path(node)
    if late
        header = "Blueprint cannot expand against current system value"
        footer = late_fail_warn(path)
    else
        header = "Blueprint value cannot be expanded"
        footer = path
    end
    print(io, "$header:\n  $message\n$footer")
end

function Base.showerror(io::IO, e::UnexpectedHookFailure)
    (; node, late) = e
    path = render_path(node)
    if late
        header = "Unexpected failure during late blueprint checking."
        footer = late_fail_warn(path)
    else
        header = "Unexpected failure during early blueprint checking."
        footer = path
    end
    print(
        io,
        "$header\n\
         This is a bug in the components library. \
         Please report if you can reproduce with a minimal example.\n\
         $footer",
    )
end

