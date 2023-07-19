module MethodMacro

using EcologicalNetworksDynamics.Framework

# The plain value to wrap in a "system" in subsequent tests.
mutable struct Value
    _member::Union{Nothing,Int64}
    Value() = new(nothing)
end
Base.copy(v::Value) = deepcopy(v)
# Willing to enjoy wrapped value properties.
Base.getproperty(v::Value, p::Symbol) = Framework.unchecked_getproperty(v, p)
Base.setproperty!(v::Value, p::Symbol, rhs) = Framework.unchecked_setproperty!(v, p, rhs)
export Value

# Use submodules to not clash component names.
# ==========================================================================================
module Invocations
using ..MethodMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pmethfails, @xmethfails
using Test

# Due to https://github.com/JuliaLang/julia/issues/51217,
# failures cannot be tested the simple way.
# Before this is solved,
# don't use @method symbol in tests,
# but only @method Path.To.Symbol forms,
# and keep associated methods in global scope.
# This unfortunately makes the tests more difficult to read :(
const S = Invocations # "Self"-module.
twice(::Value) = ()
get_m_again(v::Value) = v.m
set_m_again!(v::Value, m) = (v.m = m)
set_x!(v::Value, x) = nothing
forgot_value_type(v) = ()
miss_parameter() = ()
inconsistent_value_type(v::Int64) = ()
inconsistent_later_dep(v::Int64) = ()
wrong_depends(v) = ()
wrong_read(::Value) = ()
wrong_write(::Value) = ()
extra_read_parameter(::Value, _) = ()
miss_write_parameter(::Value) = ()
redundant(::Value) = ()
redundant(::Value, _) = ()
notasec(::Value) = ()

@testset "Invocation variations for @method macro." begin

    # Cheat with the component system here, as we are only checking macro calls:
    # the following dummy component is required by most subsequent methods,
    # although not all of them make it explicit.
    struct MZero <: Blueprint{Value} end
    Framework.expand!(v, ::MZero) = (v._member = 0)
    @component MZero
    s = System{Value}(MZero())

    get_m(v::Value) = v._member
    set_m!(v::Value, m) = (v._member = m)
    @method get_m read_as(m)
    @method set_m! write_as(m)

    # ======================================================================================
    # Valid invocations.

    #---------------------------------------------------------------------------------------
    simple_method(v::Value) = v.m
    @method simple_method

    @test simple_method(s) == 0

    #---------------------------------------------------------------------------------------
    in_block(v::Value) = v.m + 1
    @method begin
        in_block
    end

    @test in_block(s) == 1

    #---------------------------------------------------------------------------------------
    struct Marker <: Blueprint{Value} end
    @component Marker

    simple_method_with_deps(v) = v.m + 3 # (optional explicit type: inferred from deps)
    @method simple_method_with_deps depends(Marker)

    @sysfails(
        simple_method_with_deps(s),
        Method(simple_method_with_deps),
        "Requires component '$Marker'.",
    )

    @test simple_method_with_deps(s + Marker()) == 3

    #---------------------------------------------------------------------------------------
    deps_in_blocks(v) = v.m + 4
    @method begin
        deps_in_blocks
        depends(Marker)
    end

    @sysfails(deps_in_blocks(s), Method(deps_in_blocks), "Requires component '$Marker'.",)
    @test deps_in_blocks(s + Marker()) == 4

    #---------------------------------------------------------------------------------------
    infer_from_the_method_with_one_argument() = ()
    infer_from_the_method_with_one_argument(v::Value) = v.m + 5
    @method infer_from_the_method_with_one_argument

    @test infer_from_the_method_with_one_argument(s) == 5

    #---------------------------------------------------------------------------------------
    several_arguments(v::Value, b, c) = v.m + b * c
    @method several_arguments

    @test several_arguments(s, 5, 10) == 50

    #---------------------------------------------------------------------------------------
    keyword_arguments(v::Value, b, c; d = 1000) = v.m + b * c - d
    @method keyword_arguments

    @test keyword_arguments(s, 5, 10) == -950
    @test keyword_arguments(s, 5, 10; d = 10_000) == -9950

    #---------------------------------------------------------------------------------------
    explicit_empty_lists_1(::Value) = ()
    @method explicit_empty_lists_1 depends() read_as()
    explicit_empty_lists_2(::Value, _) = ()
    @method explicit_empty_lists_2 write_as()

    # ======================================================================================
    # Invocations failures.

    # Guard against double specifications.
    Framework.REVISING = false
    @method S.twice
    @xmethfails(
        (@method S.twice),
        twice,
        "Function '$twice' already marked as a method for '$System{$Value}'."
    )

    #---------------------------------------------------------------------------------------
    # Properties consistency.

    # Guard against properties overrides.
    @sysfails(
        (@method S.get_m_again read_as(m)),
        Property(m),
        "Readable property already exists.",
    )
    @sysfails(
        (@method S.set_m_again! write_as(m)),
        Property(m),
        "Writable property already exists.",
    )

    # Disallow write-only properties.
    @sysfails(
        (@method S.set_x! write_as(x)),
        Property(x),
        "Property cannot be set writable without having been set readable first.",
    )

    #---------------------------------------------------------------------------------------
    # Raw basic misuses.

    @pmethfails((@method()), ["Not enough macro input provided. Example usage:\n"],)

    @pmethfails((@method (4 + 5)), "Not a method identifier or path: :(4 + 5).",)

    @xmethfails(
        (@method S.forgot_value_type),
        forgot_value_type,
        "Without dependencies given, the system value type could not be inferred \
         from the first parameter type of '$forgot_value_type'. \
         Consider making it explicit.",
    )

    @xmethfails(
        (@method S.miss_parameter),
        miss_parameter,
        "No method of '$miss_parameter' take at least one argument.",
    )

    #---------------------------------------------------------------------------------------
    # Depends section.

    @xmethfails(# ::Int64                    # ::Value
        (@method S.inconsistent_value_type depends(Marker)),
        inconsistent_value_type,
        "Depends section: system value type has been inferred to be '$Int64' \
         based on the first parameter type(s) of '$inconsistent_value_type', \
         but '$Marker' subtypes '$Blueprint{$Value}' and not '$Blueprint{$Int64}'.",
    )

    struct MI <: Blueprint{Int64} end
    @component MI
    @xmethfails(
        (@method S.inconsistent_later_dep depends(MI, Marker)),
        inconsistent_later_dep,
        "Depends section: '$Marker' does not subtype '$Blueprint{$Int64}', \
         but '$Blueprint{$Value}'.",
    )

    @xmethfails(
        (@method S.wrong_depends depends(4 + 5)),
        wrong_depends,
        "First dependency: expression does not evaluate to a Type: :(4 + 5), \
         but to a Int64: 9."
    )

    @xmethfails(
        (@method S.wrong_depends depends(Int64)),
        wrong_depends,
        "First dependency: expression does not evaluate to a blueprint type, \
         but to 'Int64' (:Int64).",
    )

    #---------------------------------------------------------------------------------------
    # Property section.

    @pmethfails(
        (@method S.wrong_read read_as(4 + 5)),
        "Property name is not a simple identifier: :(4 + 5).",
    )

    @pmethfails(
        (@method S.wrong_write write_as(:v)),
        "Property name is not a simple identifier: :(:v).",
    )

    @xmethfails(
        (@method S.extra_read_parameter read_as(a)),
        extra_read_parameter,
        "The function '$extra_read_parameter' \
         cannot be called with exactly 1 argument of type '$Value' \
         as required to be set as a 'read' property."
    )

    @xmethfails(
        (@method S.miss_write_parameter write_as(a)),
        miss_write_parameter,
        "The function '$miss_write_parameter' \
         cannot be called with exactly 2 arguments, \
         the first one being of type '$Value', \
         as required to be set as a 'write' property."
    )

    #---------------------------------------------------------------------------------------
    # Guard against redundant sections.

    @pmethfails(
        (@method S.redundant depends(Marker) depends(A)),
        "The `depends` section is specified twice.",
    )

    @pmethfails(
        (@method S.redundant read_as(A) read_as(B)),
        "The `read_as` section is specified twice.",
    )

    @pmethfails(
        (@method S.redundant write_as(A) write_as(B)),
        "The `write_as` section is specified twice.",
    )

    @pmethfails(
        (@method S.redundant write_as(A) read_as(B)),
        "Cannot specify both `write_as` section and `read_as`.",
    )

    #---------------------------------------------------------------------------------------
    # Unexpected sections.

    @pmethfails(
        (@method S.notasec (4 + 5)),
        "Unexpected @method section. \
        Expected `depends(..)`, `read_as(..)` or `write_as(..)`. \
        Got: :(4 + 5).",
    )

    @pmethfails(
        (@method S.notasec notasection(4 + 5)),
        "Invalid section keyword: :notasection. \
         Expected `read_as` or `write_as` or `depends`.",
    )

end
end

# ==========================================================================================
module Abstracts
using ..MethodMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pmethfails, @xmethfails
using Test

@testset "Abstract component types dependencies." begin

    # Component type hierachy.
    #
    #      A
    #    ┌─┼─┐
    #    B C D
    #
    abstract type A <: Blueprint{Value} end
    struct B <: A end
    struct C <: A end
    struct D <: A end
    Framework.expand!(v, ::B) = (v._member = 1)
    Framework.expand!(v, ::C) = (v._member = 2)
    Framework.expand!(v, ::D) = (v._member = 3)
    @component B
    @component C
    @component D

    f(v, x) = x + v._member
    get_prop(v) = v._member
    set_prop!(v, x) = (v._member = x)
    @method f depends(A)
    @method get_prop depends(A) read_as(prop)
    @method set_prop! depends(A) write_as(prop)

    s = System{Value}()
    @sysfails(f(s, 5), Method(f), "Requires a component '$A'.")
    @sysfails(s.prop, Property(prop), "A component '$A' is required to read this property.")
    @sysfails(
        (s.prop = 5),
        Property(prop),
        "A component '$A' is required to write to this property."
    )

    # Any subtype enables the method and properties.
    add!(s, B())
    @test f(s, 5) == 6
    @test s.prop == 1
    s.prop = 5
    @test s.prop == 5

end
end

end
