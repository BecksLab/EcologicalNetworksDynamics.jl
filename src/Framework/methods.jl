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

# Also, methods with these exact signatures:
#
#   - method(v::Value)
#
#   - method!(v::Value, rhs)
#
# Can optionally become properties of the system/value,
# in the sense of julia's `getproperty/set_property`.
# This requires module-level bookkeeping of the associated property names.
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
depends(::Type, ::Type{<:Function}) = []
missing_dependency_for(::Type, ::Type{<:Function}, _) = nothing

# Direct call with the functions themselves.
depends(V::Type, fn::Function) = depends(V, typeof(fn))
missing_dependency_for(V::Type, fn::Function, s) = missing_dependency_for(V, typeof(fn), s)

mutable struct Property
    read::Function
    write::Union{Nothing,Function} # Leave blank if the property is read-only.
    Property(read) = new(read, nothing)
end

# {SystemWrappedValueType => {:propname => property_functions}}
const PropDict = Dict{Symbol,Property}
properties(::Type) = PropDict()

# Hack flag to avoid that the checks below interrupt the `Revise` process.
# Raise when done defining properties in the package.
global REVISING = false

# Set read property first..
# (this dynamically overrides the 'properties' method.)
function set_read_property!(V::Type, name::Symbol, mth::Function)
    current = properties(V)
    (haskey(current, name) && !REVISING) &&
        properr(V, name, "Readable property already exists.")
    current[name] = Property(mth)
    eval(quote
        properties(::Type{$V}) = $current
    end)
end

# .. and only after, and optionally, the corresponding write property.
# (this dynamically overrides the 'properties' method.)
function set_write_property!(V::Type, name::Symbol, mth::Function)
    current = properties(V)
    if !haskey(current, name)
        properr(
            V,
            name,
            "Property cannot be set writable \
             without having been set readable first.",
        )
    end
    prop = current[name]
    (isnothing(prop.write) || REVISING) ||
        properr(V, name, "Writable property already exists.")
    prop.write = mth
end

# ==========================================================================================
# Dedicated exceptions.

struct PhantomData{T} end

# About method use.
struct MethodError{V} <: Exception
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
struct PropertyError{V} <: Exception
    name::Symbol
    message::String
    _::PhantomData{V}
    PropertyError(::Type{V}, s, m) where {V} = new{V}(s, m, PhantomData{V}())
end
function Base.showerror(io::IO, e::PropertyError{V}) where {V}
    println(io, "In property '$(e.name)' of '$V': $(e.message)")
end
properr(V, n, m) = throw(PropertyError(V, n, m))
