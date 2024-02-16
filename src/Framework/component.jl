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
# Blueprint may 'bring' other components than their own,
# because they contain enough data to construct more than one component.
# There are two ways for blueprints to do so:
#
#   - Either they 'embed' other blueprints as sub-blueprints,
#     which expand as part of their own expansion process.
#     It is an error to embed a blueprint for a component already in the system.
#
#   - Or they 'imply' other blueprints,
#     which could be calculated from the data they contain if needed.
#     This does not need to happen if the implied blueprints components
#     are already in the system.
#
# Blueprint may also require that other components be present
# for their expansion process to happen correctly,
# even though the component they bring does not.
# This blueprint requirement is specified by the 'buildsfrom' function.
#
# Components also 'conflict' with each other:
#
#   - It is a failure to add a component if it conflicts
#     with another component already added.
#
#   - An abstract component cannot conflict with a component subtyping itself.
#
# Component types can be structured with a julia abstract type hierarchy:
#
#   - Requiring/Building-from an abstract component A
#     is requiring/building-from any component subtyping A.
#
#   - Conflicting with an abstract component A
#     is conflicting with any component subtyping A.
#
# It is not currently possible for an abstract component
# to 'require', 'check' or 'expand!'.
# But this might be implemented for a convincingly motivated need,
# at the cost of extending @component macro to accept abstract types.

# The parametric type 'V' for the component/blueprint
# is the type of the value wrapped by the system.
abstract type Blueprint{V} end
abstract type Component{V} end
export Blueprint, Component
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

# Every blueprint is supposed to bring exactly one major component.
# This method implements the mapping,
# and must be explicited by components devs.
componentof(::Type{B}) where {B<:Blueprint} = throw("Unspecified component for $(repr(B)).")
componentof(::B) where {B<:Blueprint} = componentof(B)

# Blueprints must be copyable, but be careful that the default (deepcopy)
# is not necessarily what component devs are after.
Base.copy(b::Blueprint) = deepcopy(b)

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

# Return non-empty list if components are required
# for this blueprint to expand,
# even though the corresponding component itself would make sense without these.
expands_from(::Blueprint) = CompsReasons()
# TODO: not formally tested yet.. but maybe wait on the framework to be refactored first?

# Specify blueprints to be automatically created and expanded
# before the focal blueprint expansion their component if not present.
# Every blueprint type listed here needs to be constructible from the focal blueprint.
implies(::Blueprint) = Type{<:Blueprint}[]
construct_implied(B::Type{<:Blueprint}, b::Blueprint) =
    throw("Implying '$B' from '$(typeof(b))' is unimplemented.")

# Same, but the listed blueprints are always created and expanded,
# resulting in an error if their components are already present.
embeds(::Blueprint) = Type{<:Blueprint}[]
construct_embedded(B::Type{<:Blueprint}, b::Blueprint) =
    throw("Embedding '$B' within '$(typeof(b))' is unimplemented.")

#-------------------------------------------------------------------------------------------
# Conflicts.

# Components that contradict each other can be grouped into mutually exclusive clusters.
# The clusters need to be defined *after* the components themselves,
# so they can all refer to each other
# as a clique of incompatible nodes in the component graph.
conflicts(::CompType) = CompsReasons()
conflicts(c::Component) = conflicts(typeof(c))

#-------------------------------------------------------------------------------------------
# Add component to the system.

# Assuming that all component addition / blueprint expansion conditions are met,
# and that brought blueprints have already been expanded,
# verify that the internal system value can still receive it.
# Framework users will use this method to verify
# that the blueprint received matches the current system state
# and that it makes sense to expand within in.
# The objective is to avoid failure during expansion,
# as it could result in inconsistent system state.
# Raise a blueprint error if not the case.
# NOTE: a failure during late check does not compromise the system state consistency,
#       but it does result in that not all blueprints brought by the focal blueprint
#       be added as expected.
#       This is to avoid the need for making the system mutable and systematically fork it
#       to possibly revert to original state in case of failure.
late_check(_, ::Blueprint) = nothing # No particular constraint to enforce by default.

# Same, but *before* brought blueprints are expanded.
# When this runs, it is guaranteed
# that there is no conflicting component in the system
# and that all required components are met,
# but, as it cannot be assumed that required components have already been expanded,
# the check should not depend on the system value.
# TODO: add formal test for this.
early_check(::Blueprint) = nothing # No particular

# The expansion step is when and the wrapped system value
# is finally modified, based on the information contained in the blueprint,
# to feature the associated component.
# This is only called if all component addition conditions are met
# and the above check passed.
# This function must not fail,
# otherwise the system ends up in a bad state.
# TODO: must it also be deterministic?
#       Or can a random component expansion happen
#       if based on consistent blueprint input and infallible.
#       Note that random expansion would result in:
#       (System{Value}() + blueprint).property != (System{Value}() + blueprint).property
#       which may be confusing.
expand!(_, ::Blueprint) = nothing # Expanding does nothing by default.

# NOTE: the above signatures for default functions *could* be more strict
# like eg. `check(::V, ::Blueprint{V}) where {V}`,
# but this would force framework users to always specify the first argument type
# or concrete calls to `check(system, myblueprint)` would be ambiguous.

# When components "optionally depend" on others,
# it may be useful to check whether they are present in the system
# within the methods above.
# To this end, an optional, additional argument
# can be received with a reference to the system,
# and can be queried for eg. `has_component(system, component)`.
# This third argument is ignored by default,
# unless in overriden methods.
late_check(v, b::Blueprint, ::System) = late_check(v, b)
expand!(v, b::Blueprint, ::System) = expand!(v, b)

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
        conflicts(sup)
    end

# Iterate over all conflicts for one particular component.
# yields (conflict_key, conflicting_component, reason)
# The yielded conflict key may be a supercomponent of the focal one.
function conflicts(C::CompType)
    Iterators.flatten(Iterators.map(super_conflict_keys(C)) do key
        Iterators.map(conflicts(key)) do (conflicting, reason)
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
# (this dynamically overrides the 'conflicts' method)
function declare_conflict(A::CompType, B::CompType, reason::Reason, err)
    vertical_guard(A, B, vertical_conflict(err))
    for (k, c, reason) in conflicts(A)
        isnothing(reason) && continue
        if B <: c
            as_K = k === A ? "" : " (as '$k')"
            as_C = B === c ? "" : " (as '$c')"
            err("Component '$A'$as_K already declared to conflict with '$B'$as_C \
                 for the following reason:\n  $(reason)")
        end
    end
    # Append new method or override by updating value.
    current = conflicts(A) # Creates a new empty value if falling back on default impl.
    current[B] = reason
    eval(quote
        conflicts(::Type{$A}) = $current
    end)
end

# Fill up a clique, not overriding any existing reason.
# (this dynamically overrides the 'conflicts' method)
function declare_conflicts_clique(err, components::CompType...)

    function process_pair(a, b)
        vertical_guard(a, b, vertical_conflict(err))
        A = typeof(a)
        current = conflicts(a)
        haskey(current, b) || (current[b] = nothing)
        eval(quote
            conflicts(::Type{$A}) = $current
        end)
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
# Specialize to refine system display component per component.
display(::V, C::CompType{V}) where {V} = "$C"
