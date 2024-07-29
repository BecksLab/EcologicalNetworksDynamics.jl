# Components are not values, but they are reified here as julia *singletons types*
# whose corresponding blueprints associate to.
#
# No concrete component type can be added twice to the system.
#
# When user wants to add components to the system,
# they provide a blueprint value which needs to be expanded into components.
#
# The data inside the blueprint is only useful to run the internal `expand!()` method once,
# and must not lend caller references to the system,
# for the internal state to not be possibly corrupted later.
# For now, this is enforced by requiring that all blueprints be copy-able.
# Only a copy of the caller blueprint is actually used for component(s) expansion.
#
# Components may 'require' other components,
# because the data they represent are meaningless without them.
# If A requires B, it means that A cannot be added in a system with no B.
#
# Components also 'conflict' with each other:
# because the data they become makes no sense within their context.
# If A conflicts with B, it means that an error should be raised
# when attempting to add A in a system with B.
#
# Component types can be structured with a julia's abstract type hierarchy:
#
#   - Conflicting with an abstract component A
#     means conflicting with any component subtyping A.
#
#   - If component B subtypes A, then A and B cannot conflict with each other.
#
# It is not currently possible for an abstract component to 'require'.
# This might be implemented in the future for a convincingly motivated need,
# at the cost of extending @component macro to produce abstract types.

# The parametric type 'V' for the component
# is the type of the value wrapped by the system.
abstract type Component{V} end
export Component

# Most framework internals work with component types
# because they can be abstract,
# most exposed methods work with concrete singleton instance.
const CompType{V} = Type{<:Component{V}}
Base.convert(::CompType{V}, c::Component{V}) where {V} = typeof(c) # Singleton ergonomy.

# Component types being singleton, we *can* infer the value from the type at runtime.
singleton_instance(C::CompType) = throw("No concrete singleton instance of '$C'.")
# Default constructors only yields singleton instances.
(C::CompType{V})() where {V} = singleton_instance(C)

# Extract underlying system wrapped value type from a component.
system_value_type(::CompType{V}) where {V} = V
system_value_type(::Component{V}) where {V} = V

#-------------------------------------------------------------------------------------------
# Requirements.

# When specifying a 'component' requirement,
# possibly invoke a 'reason' for it.
# Requirements need to be specified in terms of component types
# because it is possible to require *abstract* components.
const Reason = Option{String}
const CompsReasons{V} = OrderedDict{CompType{V},Reason}

# Specify which components are needed for the focal one to make sense.
requires(C::CompType{V}) where {V} = throw("Unspecified requirements for $C.")
requires(c::Component) = requires(typeof(c))

# List all possible blueprints types providing the component.
blueprints(C::CompType{V}) where {V} = throw("No blueprint type specified for $C.")
blueprints(c::Component{V}) where {V} = throw("No blueprint type specified for $c.")

#-------------------------------------------------------------------------------------------
# Conflicts.

# Components that contradict each other can be grouped into mutually exclusive clusters.
# The clusters need to be defined *after* the components themselves,
# so they can all refer to each other
# as a clique of incompatible nodes in the components graph.
conflicts_(::CompType{V}) where {V} = CompsReasons{V}()
conflicts_(c::Component) = conflicts_(typeof(c))
# When specialized, the above method yields a reference to underlying value,
# updated according to this module's own logic. Don't expose.

#-------------------------------------------------------------------------------------------
# Raise error based on "vertical" subtyping relations.
# (factorizing out a common check pattern)

are_subtypes(A::CompType, B::CompType) = (A <: B) ? (A, B) : (B <: A) ? (B, A) : nothing

# The provided function yields the error to emit in case the inputs subtype each other.
function vertical_guard(A::CompType, B::CompType, diverging_err::Function)
    vert = are_subtypes(A, B)
    isnothing(vert) && return
    sub, sup = vert
    diverging_err(sub, sup)
end

# Provide one special function to error in case inputs are identical.
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
        for b in components[1:(i-1)]
            process_pair(a, b)
            process_pair(b, a)
        end
    end

end

# ==========================================================================================
# Display.

# By default, strip the standard leading '_' in component type, wrap in angle brackets <>,
# and don't display blueprint details within component values.
# NOTE: this enhances ergonomics
# but it makes unexpected framework errors rather confusing.
# Deactivate when debugging.
strip_compname(::Type{V}, C::Type{Component{V}}) where {V} =
    "$(lstrip(String(nameof(C)), '_')){$V}"
strip_compname(::Type{V}, C::CompType{V}) where {V} = lstrip(String(nameof(C)), '_')
Base.show(io::IO, ::Type{CompType}) = print(io, "unionall CompType..?")
Base.show(io::IO, C::CompType{V}) where {V} = print(io, "<$(strip_compname(V, C))>")
Base.show(io::IO, c::Component{V}) where {V} = print(io, strip_compname(V, typeof(c)))

# More explicit terminal display.
function Base.show(io::IO, ::MIME"text/plain", C::CompType{V}) where {V}
    abs = isabstracttype(C) ? "abstract " : ""
    print(io, "$C $(crayon"black")($(abs)component type ")
    @invoke show(io::IO, C::DataType)
    print(io, ")$(crayon"reset")")
end
