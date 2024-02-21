# Components append data to a value wrapped in a 'System'.
# The system keeps track of all the blueprints used to add components their dependencies.
# It also checks that the method called and properties invoked
# do meet the components requirements.
#
# The whole framework responsibility is to ensure consistency of the wrapped value.
# As a consequence, don't leak references to it or its inner data
# unless user cannot corrupt the value state through them.
#
# The value wrapped needs to be copy-able for the system to be forked.
# So do the components blueprints.

struct RawConstruct end # Used to dispatch constructor.

# The 'system' newtypes any possible value::V.
# V needs to be copy-able for the system to be forked.
struct System{V}

    _value::V

    # Keep track of all the concrete components added:
    # type and associated singleton instance.
    _concrete::OrderedDict{CompType{V},Component{V}} # (ordered to be used as a history)

    # Components are also indexed by their possible abstract supertypes.
    _abstract::Dict{CompType{V},Set{CompType{V}}} # {Abstract -> {Concrete}}

    # Construct the initial value in-place
    # so that its state cannot be corrupted if outer aliased refs
    # are still lingering on within the caller scope.
    System{V}(args...; kwargs...) where {V} =
        new{V}(V(args...; kwargs...), OrderedDict(), Dict())

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
    System{V}() where {V} = new{V}(V(), OrderedDict(), Dict())

    # Useful when copying.
    System{V}(::Type{RawConstruct}, args...) where {V} = new{V}(args...)

end
export System

valuetype(::System{V}) where {V} = V

#-------------------------------------------------------------------------------------------
# Fork the system, recursively copying the wrapped value and every component.
function Base.copy(s::System{V}) where {V}
    value = copy(s._value)
    concrete = OrderedDict(C => comp for (C, comp) in s._concrete)
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
    props = properties_(V)
    haskey(props, p) || syserr(V, "Invalid property name: '$p'.")
    fn = props[p].read
    # Check for required components availability.
    miss = missing_dependency_for(V, fn, system)
    if !isnothing(miss)
        comp = isabstracttype(miss) ? "A component '$miss'" : "Component '$miss'"
        properr(V, p, "$comp is required to read this property.")
    end
    # Forward to method.
    fn(system)
end

function Base.setproperty!(system::System{V}, p::Symbol, rhs) where {V}
    # Authorize direct accesses to private fields.
    p in fieldnames(System) && return setfield!(system, p, rhs)
    # Search property method.
    props = properties_(V)
    haskey(props, p) || syserr(V, "Invalid property name: '$p'.")
    fn = props[p].write
    isnothing(fn) && properr(V, p, "This property is read-only.")
    # Check for required components availability.
    miss = missing_dependency_for(V, fn, system)
    if !isnothing(miss)
        comp = isabstracttype(miss) ? "A component '$miss'" : "Component '$miss'"
        properr(V, p, "$comp is required to write to this property.")
    end
    # Invoke property method, checking for available components.
    fn(system, rhs)
end

# In case the client agrees,
# also forward the properties to the wrapped value.
# Note that this happens without checking dependent components.
# Still, a lot of things *are* checked, so this 'unchecked' does *not* mean 'performant'.
function unchecked_getproperty(value::V, p::Symbol) where {V}
    perr(mess) = properr(V, p, mess)
    p in fieldnames(V) && return getfield(value, p)
    props = properties_(V)
    haskey(props, p) || perr("Neither a field of '$V' nor a property.")
    props[p].read(value)
end

function unchecked_setproperty!(value::V, p::Symbol, rhs) where {V}
    perr(mess) = properr(V, p, mess)
    p in fieldnames(V) && return setfield!(value, p, rhs)
    props = properties_(V)
    haskey(props, p) || perr("Neither a field or a property.")
    fn = props[p].write
    isnothing(fn) && properr(V, p, "Property is not writable.")
    fn(value, rhs)
end

#-------------------------------------------------------------------------------------------
# Query components.

# Iterate over all concrete components.
components(s::System) = values(s._concrete)
component_types(s::System) = keys(s._concrete)
# Restrict to the given component (super)type.
components(system::System{V}, C::CompType{V}) where {V} =
    if isabstracttype(C)
        d = system._abstract
        haskey(d, C) ? Iterators.map(T -> system._concrete[T], d[C]) : ()
    else
        d = system._concrete
        haskey(d, C) ? (d[C],) : ()
    end
components_types(system::System{V}, C::CompType{V}) where {V} =
    if isabstracttype(C)
        d = system._abstract
        haskey(d, C) ? d[C] : ()
    else
        d = system._concrete
        haskey(d, C) ? (d[C],) : ()
    end
export components, component_types

# Basic check.
has_component(s::System{V}, C::Type{<:Component{V}}) where {V} = !isempty(components(s, C))
has_component(s::System{V}, c::Component{V}) where {V} = has_component(s, typeof(c))
has_concrete_component(s::System{V}, c::Component{V}) where {V} =
    haskey(s._concrete, typeof(c))
export has_component, has_concrete_component

# List properties available for this instance.
# Returns {:propname => is_writeable}
function properties(s::System{V}) where {V}
    res = Dict{Symbol,Bool}()
    for (name, prop) in properties_(V)
        readable = isnothing(missing_dependency_for(V, prop.read, s))
        if isnothing(prop.write)
            writeable = false
        else
            writeable = isnothing(missing_dependency_for(V, prop.write, s))
        end
        readable && (res[name] = writeable)
    end
    res
end
export properties

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
    for component in values(sys._concrete)
        print(io, "\n  - $component")
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
