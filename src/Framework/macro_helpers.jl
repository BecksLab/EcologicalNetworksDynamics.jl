# The macros exposed in this module
# generate code to define new types and methods,
# and do their best to check that their input make sense,
# or emit useful error messages both during expansion and execution of the generated code.
#
# In particular, they accept arguments referring to other types within the same module,
# which may also have been defined with macros.
# Checking that these arguments are valid types is not straightforward then,
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
# As a consequence, it cannot be checked that `A` is a valid reference to an existing type
# during macro expansion.
# This check must therefore be performed during generated code execution,
# and macros must emit code for that.
# Be careful that the emitted code
# should enforce hygiene with respect to their temporary variables,
# and evaluate expressions only once (as the invoker expects)
# unless these expressions can be proved to have no side effects
# like `raw.identifiers.paths`.
#
# The following helper functions should be helpful in this respect.

# In general, these macros are expected to only be invoked at module's toplevel scopes.
# So their input is evaluated in the invocation module's toplevel scope.
# However, this prevents them to be tested against types and methods
# defined within `@testset` blocks, because these do introduce local scopes.
# Raise this flag when doing so, just as a hack for testing comfort.
LOCAL_MACROCALLS = false

# Generate code checking evaluation of invoker's expression, in invocation context.
# Optionally specify a type to be checked.
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
# into a component (blueprint type) for the given expected value type.
function to_component_type(mod, xp, value_type_var, ctx, xerr)
    quote
        C = $(to_value(mod, xp, ctx, xerr, DataType))
        Sup = Blueprint{$value_type_var}
        if !(C <: Sup)
            but = C <: Blueprint ? ", but '$(Blueprint{system_value_type(C)})'" : ""
            $xerr("$($ctx): '$C' does not subtype '$Sup'$but.")
        end
        C
    end
end

# Check whether the expression is a `raw.identifier.path`.
# If so, then it is okay to have it evaluated multiple times
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

# Extract underlying system wrapped value type from a component.
system_value_type(::Component{V}) where {V} = V
