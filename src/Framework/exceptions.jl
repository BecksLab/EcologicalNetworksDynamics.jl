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

