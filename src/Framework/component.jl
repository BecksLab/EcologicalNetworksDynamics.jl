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
requires(::CompType{V}) where {V} = () # Require nothing by default.
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
