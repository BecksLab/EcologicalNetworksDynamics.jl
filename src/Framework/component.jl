# Components are not values, but they are reified here as julia *singletons types*
# whose corresponding blueprint types are statically associated to.
#
# No concrete component type can be added twice to the system.
#
# When user wants to add a component to the system,
# they provide a blueprint value which needs to be expanded into a component.
#
# The data inside the blueprint is only useful to run the internal `expand!()` method once,
# and must not lend caller references to the system,
# so its internal state cannot be broken later.
# For now, this is enforced by requiring that all blueprints be copy-able.
# Only a copy of the caller blueprint is actually used for component expansion.
#
# This also permits that the whole system forks,
# including its own history of components as a collection of the blueprints used.
#
# Components may 'require' other components,
# because the data they bring are meaningless without them.
#
# Components also 'conflict' with each other:
# It is a failure to add a component if it conflicts
# with another component already added.
#
# Component types can be structured with a julia abstract type hierarchy:
#
#   - Conflicting with an abstract component A
#     is conflicting with any component subtyping A.
#
#   - An abstract component cannot conflict with a component subtyping itself.
#
# It is not currently possible for an abstract component to 'require',
# But this might be implemented for a convincingly motivated need,
# at the cost of extending @component macro to produce abstract types.

# The parametric type 'V' for the component
# is the type of the value wrapped by the system.
abstract type Component{V} end
export Component
## HERE: ALTERNATE DESIGN:
## Components are identified by nodes in a type hierarchy,
## and exposed as singleton instances of concrete types in this hierarchy.
##
##    abstract type Component end
##
##    struct _Omega <: Component
##       Raw::Type{Blueprint}
##       Random::Type{Blueprint}
##       Allometry::Type{Blueprint}
##       Temperature::Type{Blueprint}
##    end
##
##    module OmegaBlueprints
##       # /!\ many redundant imports to factorize here.
##       struct Raw <: Blueprint{_Omega} ... end
##       struct Random <: Blueprint{_Omega} ... end
##       ...
##    end
##
##    const Omega = _Omega(
##       OmegaBlueprints.Raw,
##       OmegaBlueprints.Random,
##       ...
##    )
##    export Omega
##
##    function (C::Omega)(args...; kwargs...)
##       if ..
##           C.Raw(...)
##       elseif ...
##           C.Random(...)
##       else ...
##       end
##    end
##
##    # Use as a blueprint constructor, but also as a blueprint namespace.
##    Omega(...)
##    Omega.Random(...)
##    Omega.Raw(...)
##
## Components require each other or conflict with each other.
## Blueprints bring each other.
## Blueprints are trees of sub-blueprints and must be treated as such.
##
## During the add! procedure:
##   - The given blueprint is visited pre-order
##     to collect the corresponding graph of sub-blueprints:
##     it is the root node, and edges are colored depending on whether
##     the brought is an 'embedding' or an 'implication'.
##     - Error if an embedded blueprint brings a component already in the system.
##     - Ignore implied blueprints bringing components already in the system.
##     - Error if any brought component is already brought by another blueprint
##       and the two differ.
##     - Error if any brought component conflicts with components already in the system.
##   - When collection is over, visit the tree post-order to:
##     - Check requirements/conflicts against components already brought in pre-order.
##     - Run the `early_check`.
##   - Visit post-order again to:
##     - Run the late `check`.
##     - Expand the blueprint into a component.
##
## Exposing the first analysis steps of the above will be useful to implement default_model.
## The default model handles a *forest* of blueprints, and needs to possibly *move* nodes
## from later blueprints to earlier blueprints so as to make the inference intuitive and
## consistent.
## Maybe this can even be implemented within the framework itself, something along:
##    add_default!(
##        forest::Blueprints;
##        without = Component[],
##        defaults = OrderedDict{Component,Function{<SomeState> ↦ Blueprint}}(),
##        state_control! = Function{new_brought/implied_blueprint ↦ edit_state},
##    )

# Most framework internals work with component types
# because they can be abstract,
# most exposed methods work with concrete singleton instance.
const CompType{V} = Type{<:Component{V}}

# Component types being singleton, we *can* infer the value from the type.
singleton_instance(C::CompType) = throw("No concrete singleton instance of '$C'.")
# Constructors only yields singleton instances.
(C::CompType{V})() where {V} = singleton_instance(C)

# Extract underlying system wrapped value type from a component.
system_value_type(::CompType{V}) where {V} = V
system_value_type(::Component{V}) where {V} = V

#-------------------------------------------------------------------------------------------
# Requirements.

# (when specifying a 'component' requirement,
# optionally use a 'component => "reason"' instead)
const Reason = Option{String}
const CompsReasons = OrderedDict{CompType,Reason}

# Specify which components are needed for the focal one to make sense.
# (these may or may not be implied/brought by the corresponding blueprints)
requires(::CompType) = CompsReasons()
requires(c::Component) = requires(typeof(c))

# List all possible blueprints for the component.
blueprints(C::CompType{V}) where {V} = throw("No blueprint specified for $C.")
blueprints(c::Component{V}) where {V} = throw("No blueprint specified for $c.")

#-------------------------------------------------------------------------------------------
# Conflicts.

# Components that contradict each other can be grouped into mutually exclusive clusters.
# The clusters need to be defined *after* the components themselves,
# so they can all refer to each other
# as a clique of incompatible nodes in the component graph.
conflicts_(::CompType) = CompsReasons()
conflicts_(c::Component) = conflicts_(typeof(c))
# When specialized, the above method yields a reference to underlying value,
# updated according to this module's own logic. Don't expose.

#-------------------------------------------------------------------------------------------
# Raise error based on "vertical" subtyping relations.
# (factorizing out a common check pattern)

are_subtypes(A::CompType, B::CompType) = (A <: B) ? (A, B) : (B <: A) ? (B, A) : nothing

function vertical_guard(A::CompType, B::CompType, diverging_err::Function)
    vert = are_subtypes(A, B)
    isnothing(vert) && return
    sub, sup = vert
    diverging_err(sub, sup)
end

function vertical_guard(A::CompType, B::CompType, err_same::Function, err_diff::Function)
    vert = are_subtypes(A, B)
    isnothing(vert) && return
    sub, sup = vert
    sub === sup && err_same()
    err_diff(sub, sup)
end

#-------------------------------------------------------------------------------------------
# The 'conflicts' mapping entries are either abstract or concrete component,
# which makes checking information for one particular component not exactly straighforward.

# (for some reason this is absent from Base)
function supertypes(T::Type)
    S = supertype(T)
    S === T ? (T,) : (T, supertypes(S)...)
end

# Iterate over all conflicting entries with the given component or a supercomponent of it.
super_conflict_keys(C::CompType) =
    Iterators.filter(supertypes(C)) do sup
        conflicts_(sup)
    end

# Iterate over all conflicts for one particular component.
# yields (conflict_key, conflicting_component, reason)
# The yielded conflict key may be a supercomponent of the focal one.
function all_conflicts(C::CompType)
    Iterators.flatten(Iterators.map(super_conflict_keys(C)) do key
        Iterators.map(conflicts_(key)) do (conflicting, reason)
            (key, conflicting, reason)
        end
    end)
end

# Guard against declaring conflicts between sub/super components.
function vertical_conflict(err)
    (sub, sup) -> begin
        it = sub === sup ? "itself" : "its own super-component '$sup'"
        err("Component '$sub' cannot conflict with $it.")
    end
end

# Declare one particular conflict with a reason.
# Guard against redundant reasons specifications.
function declare_conflict(A::CompType, B::CompType, reason::Reason, err)
    vertical_guard(A, B, vertical_conflict(err))
    for (k, c, reason) in all_conflicts(A)
        isnothing(reason) && continue
        if B <: c
            as_K = k === A ? "" : " (as '$k')"
            as_C = B === c ? "" : " (as '$c')"
            err("Component '$A'$as_K already declared to conflict with '$B'$as_C \
                 for the following reason:\n  $(reason)")
        end
    end
    # Append new method or override by updating value.
    current = conflicts_(A) # Creates a new empty value if falling back on default impl.
    if isempty(current)
        # Dynamically add method to lend reference to the value lended by `conflicts_`.
        eval(quote
            conflicts_(::Type{$A}) = $current
        end)
    end
    current[B] = reason
end

# Fill up a clique, not overriding any existing reason.
function declare_conflicts_clique(err, components::Vector{<:CompType{V}}) where {V}

    function process_pair(A::CompType{V}, B::CompType{V})
        vertical_guard(A, B, vertical_conflict(err))
        # Same logic as above.
        current = conflicts_(A)
        if isempty(current)
            eval(quote
                conflicts_(::Type{$A}) = $current
            end)
        end
        haskey(current, B) || (current[B] = nothing)
    end

    # Triangular-iterate to guard against redundant items.
    for (i, a) in enumerate(components)
        for b in components[i+1:end]
            process_pair(a, b)
            process_pair(b, a)
        end
    end

end

# ==========================================================================================
# By default, strip the standard leading '_' in component type, wrap in angle brackets <>,
# and don't display blueprint details within component values.
strip_compname(::Type{V}, C::CompType{V}) where {V} = lstrip(String(nameof(C)), '_')
Base.show(io::IO, C::CompType{V}) where {V} = print(io, "<$(strip_compname(V, C))>")
Base.show(io::IO, c::Component{V}) where {V} = print(io, strip_compname(V, typeof(c)))

# More explicit terminal display.
function Base.show(io::IO, ::MIME"text/plain", C::CompType{V}) where {V}
    print(io, "$C $(crayon"black")(component type ")
    @invoke show(io::IO, C::DataType)
    print(io, ")$(crayon"reset")")
end
