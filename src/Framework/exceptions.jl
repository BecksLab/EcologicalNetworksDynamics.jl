#-------------------------------------------------------------------------------------------
# Incorrect use of exposed macros.
# TODO: factorize them?

# User provides invalid macro arguments.
struct ItemMacroParseError <: Exception
    category::Symbol # (:component or :method)
    src::LineNumberNode # Locate macro invocation in source code.
    message::String
end

function Base.showerror(io::IO, e::ItemMacroParseError)
    print(io, "In @$(e.category) macro expansion: ")
    println(io, crayon"blue", "$(e.src.file):$(e.src.line)", crayon"reset")
    println(io, e.message)
end

# The macro expands without error,
# but during execution of the generated code,
# we figure that it had been given invalid arguments.
struct ItemMacroExecError <: Exception
    category::Symbol # (:component or :method)
    item::Union{Nothing,Type,Function} # Nothing if not yet determined.
    src::LineNumberNode
    message::String
end

function Base.showerror(io::IO, e::ItemMacroExecError)
    if isnothing(e.item)
        print(io, "In expanded @$(e.category) definition: ")
    else
        print(io, "In expanded @$(e.category) definition for '$(e.item)': ")
    end
    println(io, crayon"blue", "$(e.src.file):$(e.src.line)", crayon"reset")
    println(io, e.message)
end

# Same duo for @conflicts macro
struct ConflictMacroParseError <: Exception
    src::LineNumberNode
    message::String
end
function Base.showerror(io::IO, e::ConflictMacroParseError)
    print(io, "In @conflicts macro expansion: ")
    println(io, crayon"blue", "$(e.src.file):$(e.src.line)", crayon"reset")
    println(io, e.message)
end
struct ConflictMacroExecError <: Exception
    src::LineNumberNode
    message::String
end
function Base.showerror(io::IO, e::ConflictMacroExecError)
    print(io, "In @conflicts definition: ")
    println(io, crayon"blue", "$(e.src.file):$(e.src.line)", crayon"reset")
    println(io, e.message)
end

#-------------------------------------------------------------------------------------------
# Inconsistent system use.

struct PhantomData{T} end
abstract type SystemException <: Exception end

# About general system.
struct SystemError{V} <: SystemException
    message::String
    _::PhantomData{V}
    SystemError(::Type{VV}, m) where {VV} = new{VV}(m, PhantomData{VV}())
end

function Base.showerror(io::IO, e::SystemError{V}) where {V}
    println(io, "In system for '$V': $(e.message)")
end

syserr(V, m) = throw(SystemError(V, m))

# This exception error is thrown by the system guards
# before expansion of a blueprint, reporting a failure to meet the requirements.
# In particular, this is the exception expected to be thrown from the `check` method.
# Not parametrized over blueprint type because the exception is only thrown and caught
# within a controlled context where this type is known.
# When failure happens during expansion of implied/brought blueprints,
# a stack of failed expansions forms.
mutable struct BlueprintCheckFailure <: SystemException
    stack::Vector{Blueprint}
    message::String
    V::Union{Nothing,Type} # Setup during capture/rethrow.
    BlueprintCheckFailure(message) = new([], message, nothing)
end
checkfails(m) = throw(BlueprintCheckFailure(m))
export BlueprintCheckFailure, checkfails

function Base.showerror(io::IO, e::BlueprintCheckFailure)
    first = Ref(true)
    for blueprint in reverse(e.stack)
        if first[]
            blueprint = pop!(e.stack)
            component = componentof(blueprint)
            println(
                io,
                "\nCould not expand blueprint for '$component' \
                 to system for '$(e.V)':",
            )
        else
            blueprint = pop!(e.stack)
            component = componentof(blueprint)
            B = typeof(blueprint)
            component = component === B ? "$component" : "$component ($B)"
            println(io, "      because sub-expansion of '$component' failed:")
        end
        first[] = false
    end
    println(io, "  " * e.message)
end

# About method use.
struct MethodError{V} <: SystemException
    name::Union{Symbol,Expr} # Name or Path.To.Name.
    message::String
    _::PhantomData{V}
    MethodError(::Type{VV}, n, m) where {VV} = new{VV}(n, m, PhantomData{VV}())
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
    PropertyError(::Type{VV}, s, m) where {VV} = new{VV}(s, m, PhantomData{VV}())
end
function Base.showerror(io::IO, e::PropertyError{V}) where {V}
    println(io, "In property '$(e.name)' of '$V': $(e.message)")
end
properr(V, n, m) = throw(PropertyError(V, n, m))
