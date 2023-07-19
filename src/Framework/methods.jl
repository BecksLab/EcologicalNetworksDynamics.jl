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
global PROPERTIES = Dict{Type,Dict{Symbol,Property}}()

# Hack flag to avoid that the checks below interrupt the `Revise` process.
# Raise when done defining properties in the package.
global REVISING = false

# Set read property first..
function set_read_property!(V::Type, name::Symbol, mth::Function)
    haskey(PROPERTIES, V) || (PROPERTIES[V] = Dict())
    sub = PROPERTIES[V]
    (haskey(sub, name) && !REVISING) &&
        properr(V, name, "Readable property already exists.")
    sub[name] = Property(mth)
end

# .. and only after, and optionally, the corresponding write property.
function set_write_property!(V::Type, name::Symbol, mth::Function)
    if !haskey(PROPERTIES, V) || !haskey(PROPERTIES[V], name)
        properr(
            V,
            name,
            "Property cannot be set writable \
             without having been set readable first.",
        )
    end
    prop = PROPERTIES[V][name]
    (isnothing(prop.write) || REVISING) ||
        properr(V, name, "Writable property already exists.")
    prop.write = mth
end
