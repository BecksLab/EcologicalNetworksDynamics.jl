# Components append data to a value wrapped in a 'System'.
# The system keeps track of all the components added.
# It also checks that the method called and properties invoked
# do meet the components requirements.
#
# The whole framework responsibility is to ensure consistency of the wrapped value.
# As a consequence, don't leak references to it or its inner data
# unless user cannot corrupt the value state through them.
#
# The value wrapped needs to be constructible from no arguments,
# so the user can start with an "empty system".
#
# The value wrapped needs to be copy-able for the system to be forked.
# So do the components blueprints.

struct RawConstruct end # Used to dispatch constructor.

# The 'system' newtypes any possible value::V.
# V needs to be copy-able for the system to be forked.
struct System{V}

    _value::V

    # Keep track of all the concrete components added.
    _concrete::OrderedSet{CompType{V}} # (ordered to be used as a history)

    # Components are also indexed by their possible abstract supertypes.
    _abstract::Dict{CompType{V},Set{CompType{V}}} # {Abstract -> {Concrete}}

    # Construct the initial value in-place
    # so that its state cannot be corrupted if outer aliased refs
    # are still lingering on within the caller scope.
    System{V}(args...; kwargs...) where {V} =
        new{V}(V(args...; kwargs...), OrderedSet(), Dict())

    # Or with a starting list of components,
    # assuming the value can be constructed with no arguments.
    function System{V}(blueprints::Blueprint{V}...) where {V}
        system = System{V}()
        for bp in blueprints
            add!(system, bp)
        end
        system
    end

    # Specialize the empty case to avoid infinite recursion.
    System{V}() where {V} = new{V}(V(), OrderedSet(), Dict())

    # Useful when copying.
    System{V}(::Type{RawConstruct}, args...) where {V} = new{V}(args...)

end
export System

valuetype(::System{V}) where {V} = V

#-------------------------------------------------------------------------------------------
# Fork the system, recursively copying the wrapped value and every component.
function Base.copy(s::System{V}) where {V}
    value = copy(s._value)
    concrete = copy(s._concrete)
    abstracts = Dict(A => Set(concretes) for (A, concretes) in s._abstract)
    System{V}(RawConstruct, value, concrete, abstracts)
end

#-------------------------------------------------------------------------------------------
# The system fields are considered private, and the wrapped value in particular,
# but they can be accessed via a set of properties enabled by the components/methods.

function Base.getproperty(system::System{V}, p::Symbol) where {V}
    # Authorize direct accesses to private fields.
    p in fieldnames(System) && return getfield(system, p)
    # Search property method.
    fn = read_property(V, Val(p))
    # Check for required components availability.
    miss = missing_dependency_for(fn, system)
    if !isnothing(miss)
        comp = isabstracttype(miss) ? "A component $miss" : "Component $miss"
        properr(V, p, "$comp is required to read this property.")
    end
    # Forward to method.
    fn(system)
end

function Base.setproperty!(system::System{V}, p::Symbol, rhs) where {V}
    # Authorize direct accesses to private fields.
    p in fieldnames(System) && return setfield!(system, p, rhs)
    # Search property method.
    fn = readwrite_property(V, Val(p))
    # Check for required components availability.
    miss = missing_dependency_for(fn, system)
    if !isnothing(miss)
        comp = isabstracttype(miss) ? "A component $miss" : "Component $miss"
        properr(V, p, "$comp is required to write to this property.")
    end
    # Invoke property method.
    fn(system, rhs)
end

# In case the framework user agrees,
# also forward the properties to the wrapped value.
# Note that this happens without checking dependent components,
# and that the `; _system` hook cannot be provided then in this context.
# Still, a lot of things *are* checked, so this 'unchecked' does *not* mean 'performant'.
function unchecked_getproperty(value::V, p::Symbol) where {V}
    p in fieldnames(V) && return getfield(value, p)
    fn = read_property(V, Val(p))
    fn(value)
end

function unchecked_setproperty!(value::V, p::Symbol, rhs) where {V}
    perr(mess) = properr(V, p, mess)
    p in fieldnames(V) && return setfield!(value, p, rhs)
    fn = readwrite_property(V, Val(p))
    fn(value, rhs)
end

#-------------------------------------------------------------------------------------------
# Query components.

# Iterate over all concrete components.
component_types(s::System) = imap(identity, s._concrete)
components(s::System) = imap(singleton_instance, component_types(s))
# Restrict to the given component (super)type.
components_types(system::System{V}, C::CompType{V}) where {V} =
    if isabstracttype(C)
        d = system._abstract
        haskey(d, C) ? d[C] : ()
    else
        d = system._concrete
        C in d ? (C,) : ()
    end
components(s::System, C::CompType{V}) where {V} =
    imap(singleton_instance, components_types(s, C))
export components, component_types

# Basic check.
has_component(s::System{V}, C::Type{<:Component{V}}) where {V} = !isempty(components(s, C))
has_component(s::System{V}, c::Component{V}) where {V} = has_component(s, typeof(c))
has_concrete_component(s::System{V}, c::Component{V}) where {V} = typeof(c) in s._concrete
export has_component, has_concrete_component

# List all properties and associated functions for this type.
# Yields (property_name, fn_read, Option{fn_write}, iterator{dependencies...}).
function properties(::Type{V}) where {V}
    imap(
        ifilter(methods(read_property, Tuple{Type{V},Val}, Framework)) do mth
            mth.sig isa UnionAll && return false # Only consider concrete implementations.
            val = mth.sig.types[end]
            val <: Val ||
                throw("Unexpected method signature for $read_property: $(mth.sig)")
            val !== Val # Omit generic implementation.
        end,
    ) do mth
        val = mth.sig.types[end]
        name = first(val.parameters)
        read_fn = read_property(V, Val(name))
        write_fn = possible_write_property(V, Val(name))
        (name, read_fn, write_fn, imap(identity, depends(V, read_fn)))
    end
end
# Also feature for system type directly.
properties(::Type{System{V}}) where {V} = properties(V)
export properties

# List properties available for *this* particular instance.
# Yields (:propname, read, Option{write})
function properties(s::System{V}) where {V}
    imap(ifilter(properties(V)) do (_, read, _, _)
        isnothing(missing_dependency_for(read, s))
    end) do (name, read, write, _)
        (name, read, write)
    end
end

# List *unavailable* properties for this instance
# along with the components missing to support them.
# Yields (:propname, read, Option{write}, iterator{missing_dependencies...})
function latent_properties(s::System{V}) where {V}
    imap(ifilter(properties(V)) do (_, read, _, _)
        !isnothing(missing_dependency_for(read, s))
    end) do (name, read, write, deps)
        (name, read, write, ifilter(d -> !has_component(s, d), deps))
    end
end
export latent_properties

# Consistency + REPL completion.
Base.propertynames(s::System) = imap(first, properties(s))

#-------------------------------------------------------------------------------------------

# Basic recursive equivalence relation.
function equal_fields(a::T, b::T) where {T}
    for name in fieldnames(T)
        u, v = getfield.((a, b), name)
        u == v || return false
    end
    true
end
Base.:(==)(a::System{U}, b::System{V}) where {U,V} = U == V && equal_fields(a, b)
Base.:(==)(a::Blueprint{U}, b::Blueprint{V}) where {U,V} =
    U == V && typeof(a) == typeof(b) && equal_fields(a, b)

#-------------------------------------------------------------------------------------------
# Display.
function Base.show(io::IO, sys::System)
    n = length(sys._concrete)
    print(io, "$(typeof(sys)) with $n component$(s(n)).")
end

function Base.show(io::IO, ::MIME"text/plain", sys::System)
    n = length(sys._concrete)
    S = typeof(sys)
    rs = repr(MIME("text/plain"), S)
    print(io, "$rs with $n component$(eol(n))")
    for C in sys._concrete
        print(io, "\n  - $C")
    end
end
s(n) = (n > 1) ? "s" : ""
eol(n) = s(n) * (n == 0 ? "." : ":")

# ==========================================================================================
# Dedicated exceptions.

struct SystemError{V} <: SystemException
    message::String
    _::PhantomData{V}
    SystemError(::Type{V}, m) where {V} = new{V}(m, PhantomData{V}())
end

function Base.showerror(io::IO, e::SystemError{V}) where {V}
    println(io, "In system for '$V': $(e.message)")
end

syserr(V, m) = throw(SystemError(V, m))
