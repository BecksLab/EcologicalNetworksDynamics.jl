# Dedicate to exceptions emitted by various parts of the project.
# Export test macros to the various test submodules.
# TODO: ease boilerplate here.

using MacroTools
using .TestFailures
import EcologicalNetworksDynamics.AliasingDicts: AliasingError
import EcologicalNetworksDynamics.Framework:
    Framework,
    ItemMacroParseError,
    ItemMacroExecError,
    SystemException,
    ConflictMacroParseError,
    ConflictMacroExecError,
    BlueprintCheckFailure

# ==========================================================================================
# Check failures in aliasing systems.

function TestFailures.check_exception(e::AliasingError, name, message_pattern)
    e.name == name ||
        error("Expected error for '$name' aliasing system, got '$(e.name)' instead.")
    TestFailures.check_message(message_pattern, eval(e.message))
end

macro xaliasfails(xp, name, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($(AliasingError) => ($name, $mess)),
        true,
    )
end

export @aliasfails
macro aliasfails(xp, name, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($(AliasingError) => ($name, $mess)),
        false,
    )
end
export @aliasfails

# ==========================================================================================
# Framework.

#-------------------------------------------------------------------------------------------
# Check failures in macro expansion.

function TestFailures.check_exception(e::ItemMacroParseError, category, message_pattern)
    e.category == category ||
        error("Expected '@$category' macro expansion error, got '@$(e.category)'.")
    TestFailures.check_message(message_pattern, e.message)
end

# Convenience macros for the test suite.
macro pcompfails(xp, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroParseError => (:component, $mess)),
        true,
    )
end
macro pmethfails(xp, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroParseError => (:method, $mess)),
        true,
    )
end
export @pcompfails, @pmethfails

#-------------------------------------------------------------------------------------------
# Check failures in macro execution.

function TestFailures.check_exception(
    e::ItemMacroExecError,
    category,
    item,
    message_pattern,
)
    e.category == category ||
        error("Expected '@$category' macro execution error, got '@$(e.category)'.")
    e.item === item ||
        error("Expected '$item' item in @$category execution error, got $(e.item).")
    TestFailures.check_message(message_pattern, e.message)
end

# Convenience macros for the tests suite.
macro xcompfails(xp, item, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroExecError => (:component, $item, $mess)),
        false,
    )
end
macro xmethfails(xp, item, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroExecError => (:method, $item, $mess)),
        false,
    )
end
export @xcompfails, @xmethfails

# Same duo for @conflicts macro.
TestFailures.check_exception(e::ConflictMacroParseError, mp) =
    TestFailures.check_message(mp, e.message)
TestFailures.check_exception(e::ConflictMacroExecError, mp) =
    TestFailures.check_message(mp, e.message)
macro pconffails(xp, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ConflictMacroParseError => ($mess,)),
        true,
    )
end
macro xconffails(xp, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ConflictMacroExecError => ($mess,)),
        false,
    )
end
export @pconffails, @xconffails

#-------------------------------------------------------------------------------------------
# Test system use errors.

# Abstract over the other types of system errors.
# For now, they either only need `.message` checking
# or they also have a `name::Symbol` member.

# Simple version for exceptions with no type parameter.
# TODO: this matches no exception now?
function TestFailures.check_exception(e::SystemException, mod, E, name, message_pattern)
    typeof(e) === E || error("Expected system exception type:\n  $E\ngot instead:\n  $e")
    isnothing(name) ||
        e.name == name ||
        error("Expected error name :$name, got $(repr(e.name)) for $E.")
    # Evaluate message pattern late because it needs to expand with component type.
    message_pattern = Core.eval(mod, message_pattern)
    TestFailures.check_message(message_pattern, e.message)
end

# Special-case the check exceptions with the blueprints stack.
function TestFailures.check_exception(e::BlueprintCheckFailure, stack, message_pattern)
    stack == typeof.(e.stack) || error("Expected error stack: $stack\n\
                                        Received instead    : $(e.stack).")
    TestFailures.check_message(message_pattern, e.message)
end

# Sophisticated version for exceptions like `MethodError` with type parameters.
function TestFailures.check_exception(
    e::SystemException,
    mod,
    union_xp,
    type_parms_xp, # (there used to be several ones, keep this possible)
    name,
    message_pattern,
)
    # Evaluate error type late because we need to wait before all expansions happen.
    ev(x) = Core.eval(mod, x)
    E = ev(:($union_xp{$(map(ev, type_parms_xp))...}))
    TestFailures.check_exception(e, mod, E, name, message_pattern)
end

# Use with `ErrName(name)` if the type to check has a `.name` field.
# Otherwise `ErrName` will just do.
# Implicit value type parameter for error type in this context is always `Value`,
# assuming such a type exists in the macro invocation context eg. in the test suite.
# Special-case `BlueprintCheckFailure` as it doesn't have a type parameter.
macro sysfails(xp, input, mess)
    assert_symbol(x) =
        x isa Symbol ||
        throw("Incorrect use of @sysfails test macro: not a symbol: $(repr(x)).")
    assert_path(x) =
        (x isa Symbol || x isa Expr && x.head == :.) ||
        throw("Incorrect use of @sysfails test macro: not an identifier path: $(repr(x)).")
    #! format: off
    @capture(
        input,
        Check(stack__) |
        errunion_(name_) |
        errunion_
    )
    #! format: on
    if isnothing(stack)
        assert_symbol(errunion)
        isnothing(name) || assert_symbol(name)
        name = Meta.quot(name)
        errparms = [:Value]
        # Prepare for evaluation within this testing context.
        errunion = Symbol(errunion, :Error)
        errunion = :($Framework.$errunion)
        E = SystemException
        args = :($__module__, $errunion, $errparms, $name, $mess)
    else
        assert_path.(stack)
        name = nothing
        stack = Expr(:vect, reverse(stack)...)
        E = BlueprintCheckFailure
        args = :($stack, $mess)
    end
    TestFailures.failswith(__source__, __module__, xp, :($E => $args), false)
end
export @sysfails

# ==========================================================================================
# Graph Views.

import EcologicalNetworksDynamics.GraphViews

function TestFailures.check_exception(e::GraphViews.ViewError, type, message_pattern)
    e.type == type ||
        error("Expected error for view type '$type', got '$(e.type)' instead.")
    TestFailures.check_message(message_pattern, eval(e.message))
end

macro viewfails(xp, type, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($(GraphViews.ViewError) => ($type, $mess)),
        false,
    )
end
export @viewfails
