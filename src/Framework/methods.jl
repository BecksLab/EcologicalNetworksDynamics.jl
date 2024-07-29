# Methods add functionalities to the system,
# in the sense that components add the *data* while methods add the *code*.
#
# Methods are never "added" onto the system's value. They are already there.
# But they come in two styles:
#
#   - method(s::System, ..) -> Checks that required components are loaded before it runs.
#
#   - method(v::Value, ..) -> Runs, with undefined behaviour if components are missing.
#
# Only the second one needs to be specified by the framework user,
# along with its components dependencies.
#
# If the method needs to run differently
# depending on the presence/absence of other components,
# then the following hook is provided:
#
#   - method(v::Value, ..; .., _system::System) <- to enable has_component(_system, C).
#
# Also, methods with these exact signatures:
#
#   - method(v::Value)  (+ optional `; _system`)
#
#   - method!(v::Value, rhs) ( + optional `; _system`)
#
# Can optionally become properties of the system/value,
# in the sense of julia's `getproperty/set_property`.
#
# The properties also come in two styles:
#
#   - system.property -> Checks that the required components exist.
#
#   - value.property -> Runs and see what happens.
#
# Method's polymorphism use julia dispatch over function types.
# The wrapped system value type must always be specified.

# Methods depend on nothing by default.
depends(V::Type, ::Type{<:Function}) = CompType{V}[]
missing_dependency_for(::Type, ::Type{<:Function}, _) = nothing

# Direct call with the functions themselves.
depends(V::Type, fn::Function) = depends(V, typeof(fn))
missing_dependency_for(V::Type, fn::Function, s) = missing_dependency_for(V, typeof(fn), s)

# Map wrapped system value and property name to the corresponding function.
read_property(V::Type, ::Val{name}) where {name} =
    throw(PropertyError(V, name, "Unknown property."))
write_property(V::Type, ::Val{name}) where {name} =
    throw(PropertyError(V, name, "Unknown property."))

has_read_property(V::Type, name::Symbol) =
    try
        read_property(V, Val(name))
        true
    catch e
        e isa PropertyError || rethrow(e)
        false
    end

possible_write_property(V::Type, name::Symbol) =
    try
        write_property(V, Val(name))
    catch e
        e isa PropertyError || rethrow(e)
        nothing
    end

has_write_property(V::Type, name::Symbol) = !isnothing(possible_write_property(V, name))

function readwrite_property(V::Type, name::Symbol)
    read_property(V, Val(name)) # Errors if not even 'read-'.
    try
        write_property(V, Val(name))
    catch e
        e isa PropertyError || rethrow(e)
        properr(V, name, "This property is read-only.")
    end
end

# Hack flag to avoid that the checks below interrupt the `Revise` process.
# Raise when done defining properties in the package.
global REVISING = false

# Set read property first..
function set_read_property!(V::Type, name::Symbol, fn::Function)
    REVISING ||
        has_read_property(V, name) ||
        properr(V, name, "Readable property already exists.")
    # Dynamically add method to connect property name to the given function.
    name = Meta.quot(name)
    eval(quote
        read_property(::Type{$V}, ::Val{$name}) = $fn
    end)
end

# .. and only after, and optionally, the corresponding write property.
function set_write_property!(V::Type, name::Symbol, fn::Function)
    has_read_property(V, name) || properr(
        V,
        name,
        "Property cannot be set writable \
         without having been set readable first.",
    )
    REVISING ||
        has_write_property(V, name) && properr(V, name, "Writable property already exists.")
    name = Meta.quot(name)
    eval(quote
        write_property(::Type{$V}, ::Val{$name}) = $fn
    end)
end

# ==========================================================================================
# Dedicated exceptions.

# About method use.
struct MethodError{V} <: SystemException
    name::Union{Symbol,Expr} # Name or Path.To.Name.
    message::String
    _::PhantomData{V}
    MethodError(::Type{V}, n, m) where {V} = new{V}(n, m, PhantomData{V}())
end
function Base.showerror(io::IO, e::MethodError{V}) where {V}
    println(io, "In method '$(e.name)' for '$V': $(e.message)")
end
metherr(V, n, m) = throw(MethodError(V, n, m))

# About properties use.
struct PropertyError{V} <: SystemException
    name::Symbol
    message::String
    _::PhantomData{V}
    PropertyError(::Type{V}, s, m) where {V} = new{V}(s, m, PhantomData{V}())
end
function Base.showerror(io::IO, e::PropertyError{V}) where {V}
    println(io, "In property '$(e.name)' of '$V': $(e.message)")
end
properr(V, n, m) = throw(PropertyError(V, n, m))
