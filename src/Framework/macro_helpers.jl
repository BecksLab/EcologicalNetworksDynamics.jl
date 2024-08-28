# The macros exposed in this module
# generate code to correctly define new components, blueprints and methods,
# and check that their input make sense.
# On incorrect input, they emit
# useful error messages either during expansion
# or execution of the generated code.
#
# In particular, they accept arguments referring to
# other types within the same invocation module,
# which may also have been defined with macros.
# Checking that these arguments are valid types
# is not straightforward then,
# because in the following:
#
#   @create_type A
#   @create_type B depends_on_type(A)
#
# It cannot be enforced that the second macro expansion
# will happen *after* the code resulting of the first expansion is executed.
# For instance, both expansions happen before any execution in the following:
#
#   begin
#     @create_type A
#     @create_type B depends_on_type(A)
#   end
#
# As a consequence, it cannot be checked that `A`
# is a valid reference to an existing type during macro expansion.
# This check must therefore be performed during generated code execution,
# and macros must emit code for that.
# When developping these macros,
# be careful that the emitted code
# should enforce hygiene with respect to their temporary variables,
# and evaluate expressions only once (as the invoker expects)
# unless the expressions can be assumed to have no side effects
# like `raw.identifiers.paths`.
#
# The following helper functions should be helpful in this respect.

# In general, these macros are expected to only be invoked in
# user's modules toplevel scopes.
# So their input is evaluated in the invocation module's toplevel scope.
# However, this prevents them from being tested against types and methods
# defined within `@testset` blocks, because these do introduce local scopes.
# Raise this flag when doing so, just as a hack for testing comfort.
LOCAL_MACROCALLS = false

# Generate code checking evaluation of invoker's expression, in invocation context.
# Optionally specify a type for the evaluation result to be checked against.
function to_value(mod, expression, context, error_out, type = nothing)
    evcode = if LOCAL_MACROCALLS
        # Evaluate as given in local invocation scope.
        esc(expression)
    else
        # Evaluate at toplevel scope of invocation module.
        :($Core.eval($mod, $(Meta.quot(expression))))
    end
    ev = :(
        try
            $evcode
        catch _
            $error_out($"$context: expression does not evaluate: $(repr(expression)). \
                        (See error further down the exception stack.)")
        end
    )
    isnothing(type) || (
        ev = quote
            val = $ev
            val isa $type || $error_out(
                "$($context): expression does not evaluate to a $($type): \
                 $($(repr(expression))), but to a $(typeof(val)): $val.",
            )
            val
        end
    )
    ev
end

# Special-case of the above when the expression is expected to evaluate
# into a component for the given expected value type.
function to_component(mod, xp, value_type_var, ctx, xerr)
    quote
        comp = $(to_value(mod, xp, ctx, xerr, Component))
        Sup = Component{$value_type_var}
        if !(comp isa Sup)
            but = comp isa Component ? ", but '$(Component{system_value_type(comp)})'" : ""
            $xerr("$($ctx): '$comp' is not of type '$Sup'$but.")
        end
        comp
    end
end

# Same for a blueprint type.
function to_blueprint_type(mod, xp, value_type_var, ctx, xerr)
    quote
        B = $(to_value(mod, xp, ctx, xerr, DataType))
        Sup = Blueprint{$value_type_var}
        if !(B <: Sup)
            but = B <: Blueprint ? ", but '$(Blueprint{system_value_type(B)})'" : ""
            $xerr("$($ctx): '$B' does not subtype '$Sup'$but.")
        end
        B
    end
end

# Component dependencies are either specified
# as singleton instances (because it is convenient),
# or as component type (because they may be abstract).
# Yet only extract corresponding types.
function to_dependency(mod, xp, ctx, xerr)
    quote
        dep = $(to_value(mod, xp, ctx, xerr, Union{Component,<:CompType}))
        dep isa Type ? dep : typeof(dep)
    end
end

# Check whether the expression is a `raw.identifier.path`.
# If so, then we assume it produces no side effect
# so it is okay to have it evaluated multiple times
# within the generated code.
function is_identifier_path(xp)
    xp isa Symbol && return true
    if xp isa Expr
        xp.head == :. || return false
        path, last = xp.args
        last isa QuoteNode || return false
        is_identifier_path(path) && is_identifier_path(last.value)
    else
        false
    end
end

# Append path to a module,
# not straightforward because with U = :(a.b) and V = :(c.d),
# then :($U.$V) is *not* :(a.b.c.d) but :(a.b.:(c.d)) and most likely unusable.
# But cat_path(U, V) *is* :(a.b.c.d).
function cat_path(mod, path::Expr)
    # Collect all path steps.
    steps = Symbol[]
    current = path
    err() = argerr("Not a raw path of identifiers: $(repr(path)).")
    while !(current isa Symbol)
        current.head == :. || err()
        current, step = current.args
        step isa QuoteNode || err()
        step.value isa Symbol || err()
        push!(steps, step.value)
    end
    push!(steps, current)
    # Construct final expression with reverse read.
    res = mod
    for step in reverse(steps)
        res = :($res.$step)
    end
    res
end
# Trivial case.
cat_path(mod, id::Symbol) = :($mod.$id)

# ==========================================================================================
# Dedicated exceptions.

# User provides invalid macro arguments.
struct ItemMacroParseError <: Exception
    category::Symbol # (:component, :blueprint or :method)
    src::LineNumberNode # Locate macro invocation in user source code.
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
    category::Symbol # (:component, :blueprint or :method)
    item::Union{Nothing,Type,Function,Symbol} # Nothing if not yet determined.
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

#-------------------------------------------------------------------------------------------
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
