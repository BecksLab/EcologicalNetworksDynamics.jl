# Components are not values, but they are reified here as julia *types*
# whose instances are the blueprints required to construct them.
#
# No concrete component type can be added twice to the system.
#
# When users wants to add a component to the system,
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
# Components require other components:
#
#   - Either because the data it brings is meaningless without the requirement ('requires').
#
#   - Or because it actually adds other components prior to its own expansion process.
#     TODO: This is actually a property of the *blueprint* and not exactly the component,
#           and this should be clarified in future refactoring of the framework.
#     In this situation, the blueprint either:
#       - Automatically adds them if not already present ('implies').
#       - Automatically adds them but errors if already present ('brings').
#     TODO: unify the above two situations into just 'bringing' with different behaviours?
#
#   - Or because the blueprint just needs the data
#     for its own check/expand! process ('buildsfrom'),
#     but the component data produced after expansion is meaningful even without them.
#
# Components also 'conflict' with each other:
#
#   - It is a failure to add a component if it conflicts
#     with another component already added.
#
#   - An abstract component type cannot conflict with a component subtyping itself.
#
# Component types can be structured with a julia abstract type hierarchy:
#
#   - Requiring an abstract component A
#     is requiring that any component subtyping A be present.
#
#   - Implying / Bringing / Building-from an abstract component A
#     is implying or bringing or building-from some component subtyping A
#     but it is unspecified which one.
#
#   - Conflicting with an abstract component A
#     is conflicting with any component subtyping A.
#
# It is not currently possible for an abstract component
# to 'require', 'imply', 'bring', 'buildfrom', 'check' or 'expand!'.
# But this might be implemented for a convincingly motivated need,
# at the cost of extending @component macro to accept abstract types.
#
# The parametric type 'V' for the component/blueprint
# is the type of the value wrapped by the system.
abstract type Blueprint{V} end
const Component{V} = Type{<:Blueprint{V}} # TODO: this is too constrained: refactor.
export Blueprint, Component

# Extract component from blueprint or blueprint type.
# Not actually used within the framework logic,
# because it needs to be all refactored in this respect,
# but useful to framework users for future compatibility.
# Override to fix semantics when implementing the 'several blueprints for one component' pattern.
componentof(::Type{B}) where {B<:Blueprint} = B
componentof(bp::B) where {B<:Blueprint} = componentof(typeof(bp))

# Blueprints must be copyable, but be careful that the default (deepcopy)
# is not necessarily what component devs are after.
Base.copy(b::Blueprint) = deepcopy(b)

#-------------------------------------------------------------------------------------------
# Requirements.

# Specify which components are needed for the focal one to make sense.
# like [Component => "reason", OtherComponent].
# (these may or may not be implied/brought by the corresponding blueprints)
requires(::Component) = Component[]

# Same, but the returned components are needed for the expansion process
# of this particular blueprint,
# even though the corresponding component itself would make sense without these.
buildsfrom(::Blueprint) = Union{Component,Pair{Component,String}}[]
# TODO: not formally tested yet.. but maybe wait on the framework to be refactored first?

# Specify which components are automatically added
# during blueprint expansion if not present.
# Every blueprint type listed here needs to be constructible from the focal blueprint.
implies(::Blueprint) = Type{<:Blueprint}[]
construct_implied(B::Type{<:Blueprint}, b::Blueprint) =
    throw("Implying '$B' from '$(typeof(b))' is unimplemented.")
# Same, but these components need to be not present.
brings(::Blueprint) = Type{<:Blueprint}[]
construct_brought(B::Type{<:Blueprint}, b::Component) =
    throw("Bringing '$B' from '$(typeof(b))' is unimplemented.")

#-------------------------------------------------------------------------------------------
# Conflicts.

# TODO: it appears that these global dicts (+ the one for PROPERTIES)
#       are maybe not actually required, since the mapping Component ↦ information
#       could very well be implemented with traditional julia dispatched methods.
#       Check this out and remove them.
# Components that contradict each other can be grouped into mutually exclusive clusters.
# The clusters need to be defined *after* the components themselves,
# so they can all refer to each other
# as a clique of incompatible nodes in the component graph.
# {component => {conflicting_component => reason}}
const Reason = Union{Nothing,String}
global CONFLICTS = Dict{Type,OrderedDict{Component,Reason}}()
# Consistency of the above value is ensured by the exposed @conflicts macro.

#-------------------------------------------------------------------------------------------
# Add component to the system.

# Assuming that all component addition conditions are met
# verify that the internal system value can still receive it.
# Typically: the blueprint value must match the current value structure.
# The objective is to avoid failure during expansion,
# as these would result in inconsistent system state.
# Raise a blueprint error if not the case.
check(_, ::Blueprint) = nothing # No particular constraint by default.

# Quick hook patch: run checks before implied/brought components are addressed
# and the corresponding blueprints possibly constructed.
# When this runs, it is guaranteed
# that there is no conflicting component in the system
# and that all 'required' components are met,
# but nothing is yet known about 'implied/brought' components.
# TODO: add formal test for this.
early_check(_, ::Blueprint) = nothing

# The expansion step is when a particular blueprint value is read
# and the wrapped system value finally modified to feature the associated component.
# This is only called if all component addition conditions are met
# and the above check passed.
# This function must not fail,
# otherwise the system ends up in a bad state.
# TODO: must it also be deterministic?
# Or can a random component expansion happen
# if based on consistent blueprint input and infallible.
# Note that random expansion would result in:
# (System{Value}() + blueprint).property != (System{Value}() + blueprint).property
# which may be confusing.
expand!(_, ::Blueprint) = nothing # Expanding does nothing by default.

# NOTE: the above signatures for default functions could be more strict
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
check(v, b::Blueprint, _) = check(v, b)
early_check(v, b::Blueprint, _) = early_check(v, b)
expand!(v, b::Blueprint, _) = expand!(v, b)

#-------------------------------------------------------------------------------------------
# Raise error based on "vertical" subtyping relations.
# (factorizing out a common check pattern)

are_subtypes(a::Component, b::Component) = (a <: b) ? (a, b) : (b <: a) ? (b, a) : nothing

function vertical_guard(a::Component, b::Component, diverging_err::Function)
    vert = are_subtypes(a, b)
    isnothing(vert) && return
    sub, sup = vert
    diverging_err(sub, sup)
end

function vertical_guard(a::Component, b::Component, err_same::Function, err_diff::Function)
    vert = are_subtypes(a, b)
    isnothing(vert) && return
    sub, sup = vert
    sub === sup && err_same()
    err_diff(sub, sup)
end

#-------------------------------------------------------------------------------------------
# The CONFLICT global dict either contains abstract or concrete type as entries,
# which makes checking information for one particular type not as simple as haskey(C, k).

# (for some reason this is absent from Base)
function supertypes(T::Type)
    S = supertype(T)
    S === T ? (T,) : (T, supertypes(S)...)
end

# Iterate over all keys in CONFLICTS with the given type or a supertype of it.
super_conflict_keys(c::Component) =
    Iterators.filter(supertypes(c)) do sup
        haskey(CONFLICTS, sup)
    end

# Iterate over all conflicts for one particular component type.
# yields (conflict_key, conflicting_component, reason)
# The yielded conflict key may be a supertype of the given component.
function conflicts(c::Component)
    Iterators.flatten(Iterators.map(super_conflict_keys(c)) do key
        Iterators.map(CONFLICTS[key]) do (conflicting, reason)
            (key, conflicting, reason)
        end
    end)
end

# Guard against declaring conflicts between sub/super components.
function vertical_conflict(err)
    (sub, sup) -> begin
        it = sub === sup ? "itself" : "its own supertype '$sup'"
        err("Component '$sub' cannot conflict with $it.")
    end
end

# Declare one particular conflict with a reason.
# Guard against redundant reasons specifications.
function declare_conflict(a::Component, b::Component, reason, err)
    vertical_guard(a, b, vertical_conflict(err))
    needs_new_entry = true
    for (k, c, reason) in conflicts(a)
        k === a && (needs_new_entry = false)
        isnothing(reason) && continue
        if b <: c
            as_K = k === a ? "" : " (as '$k')"
            as_C = b === c ? "" : " (as '$c')"
            err("Component '$a'$as_K already declared to conflict with '$b'$as_C \
                 for the following reason:\n  $(reason)")
        end
    end
    sub = needs_new_entry ? (CONFLICTS[a] = OrderedDict{Component,Reason}()) : CONFLICTS[a]
    sub[b] = reason
end

# Fill up a clique, not overriding any existing reason.
# (called from @conflict macro)
function declare_conflicts_clique(err, components::Component...)

    function process_pair(a, b)
        vertical_guard(a, b, vertical_conflict(err))
        if haskey(CONFLICTS, a)
            sub = CONFLICTS[a]
            haskey(sub, b) || (sub[b] = nothing)
        else
            CONFLICTS[a] = OrderedDict{Component,Reason}(b => nothing)
        end
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
display(::V, C::Component{V}) where {V} = "$C"
