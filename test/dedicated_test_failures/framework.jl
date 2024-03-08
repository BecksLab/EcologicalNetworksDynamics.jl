# Check failures in components framework.

import EcologicalNetworksDynamics.Framework:
    AddError,
    BlueprintCheckFailure,
    BroughtAlreadyInValue,
    CompType,
    Component,
    ConflictMacroExecError,
    ConflictMacroParseError,
    ConflictWithSystemComponent,
    Framework,
    HookCheckFailure,
    ItemMacroExecError,
    ItemMacroParseError,
    MissingRequiredComponent,
    SystemException

#-------------------------------------------------------------------------------------------
# Check failures in macro expansion.

function TestFailures.check_exception(e::ItemMacroParseError, category, message_pattern)
    e.category == category ||
        error("Expected '@$category' macro expansion error, got '@$(e.category)'.")
    TestFailures.check_message(message_pattern, e.message)
end

# Convenience macros for the test suite.
macro pbluefails(xp, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroParseError => (:blueprint, $mess)),
        true,
    )
end
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
export @pbluefails, @pcompfails, @pmethfails

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
macro xbluefails(xp, item, mess)
    TestFailures.failswith(
        __source__,
        __module__,
        xp,
        :($ItemMacroExecError => (:blueprint, $item, $mess)),
        false,
    )
end
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
export @xbluefails, @xcompfails, @xmethfails

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
# TODO: does this match any exception now?
function TestFailures.check_exception(e::SystemException, mod, E, name, message_pattern)
    typeof(e) === E || error("Expected system exception type:\n  $E\ngot instead:\n  $e")
    isnothing(name) ||
        e.name == name ||
        error("Expected error name :$name, got $(repr(e.name)) for $E.")
    # Evaluate message pattern late because it needs to expand with component type.
    message_pattern = Core.eval(mod, message_pattern)
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
# Special-case `AddError` as it requires more (arbitrary) information checking.
macro sysfails(xp, input, mess = nothing)
    assert_symbol(x) =
        x isa Symbol ||
        throw("Incorrect use of @sysfails test macro: not a symbol: $(repr(x)).")
    assert_path(x) =
        (x isa Symbol || x isa Expr && x.head == :.) ||
        throw("Incorrect use of @sysfails test macro: not an identifier path: $(repr(x)).")
    #! format: off
    @capture(
        input,
        Add(AddName_, fields__) |
        errunion_(name_) |
        errunion_
    )
    #! format: on
    if isnothing(fields)
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
        # Evaluate expected error in macro definition context.
        ExceptionType = eval(AddName)
        E = :($AddError{Value})
        # Evaluate expected fields within macro invocation context.
        fields = Expr(:vect, fields...)
        args = :($ExceptionType, $fields)
    end
    TestFailures.failswith(__source__, __module__, xp, :($E => $args), false)
end
export @sysfails

#-------------------------------------------------------------------------------------------
# Sophisticated version for AddError, because all fields are checked
# according to framework dedicated logic.
function TestFailures.check_exception(e::AddError, expected_type, fields)
    e = e.e
    # Check type.
    E = typeof(e)
    nE = nameof(E)
    E == expected_type || error("Expected '$expected_type' error, got '$E' instead.")
    # Check field values.
    names = fieldnames(E)
    actual = [getfield(e, name) for name in names]
    expected = fields
    la, le = length.((actual, expected))
    s(n) = n > 1 ? "s" : ""
    la == le || error("Exception '$nE' contains $la field$(s(la)), \
                       but $le field$(s(le)) were expected.")
    for (name, a, e) in zip(names, actual, expected)
        if a isa Framework.Node
            e isa Vector ||
                error("Cannot compare node field $nE.$name to $(repr(e))::$(typeof(e)).")
            check_path(a, e)
        elseif a isa String
            message = a
            pattern = e
            TestFailures.check_message(pattern, message)
        elseif a isa CompType
            te = e isa Component ? typeof(e) : e
            a === te ||
                error("Expected component for $nE.$name:\n  $te\nfound instead:\n  $a")
        else
            ta, te = typeof.((a, e))
            ta === te || error("Expected type for $nE.$name:\n  $te\nfound instead:\n  $ta")
            a == e || error("Expected value for $nE.$name:\n  $e\nfound instead:\n  $a")
        end
    end
end

function check_path(node::Framework.Node, expected)
    actual = Framework.path(node)
    actual == expected || error("Node does not match the expected path:\
                                 \n  $expected\nactual path:\n  $actual")
end
