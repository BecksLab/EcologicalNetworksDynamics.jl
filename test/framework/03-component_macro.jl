module ComponentMacro

# The plain value to wrap in a "system" in subsequent tests.
struct Value end
Base.copy(v::Value) = deepcopy(v)
export Value

# Use submodules to not clash component names.
# ==========================================================================================
module Invocations
using ..ComponentMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pcompfails, @xcompfails
using Test

@testset "Invocation variations of @component macro." begin

    # ======================================================================================
    # Valid invocations.

    #---------------------------------------------------------------------------------------
    struct EmptyMarker <: Blueprint{Value} end
    @component EmptyMarker

    s = System{Value}(EmptyMarker())
    @test has_component(s, EmptyMarker)

    #---------------------------------------------------------------------------------------
    struct MarkerInBlock <: Blueprint{Value} end
    @component begin
        MarkerInBlock
    end

    s = System{Value}(MarkerInBlock())
    @test has_component(s, MarkerInBlock)

    #---------------------------------------------------------------------------------------
    struct MarkerExpands <: Blueprint{Value} end
    Framework.expand!(_, ::MarkerExpands) = nothing
    @component MarkerExpands

    s = System{Value}(MarkerExpands())
    @test has_component(s, MarkerExpands)

    #---------------------------------------------------------------------------------------
    struct EmptyMarkerWithinBlockWithRequirements <: Blueprint{Value} end
    @component begin
        EmptyMarkerWithinBlockWithRequirements
        requires(MarkerInBlock)
    end

    @sysfails(
        (s + EmptyMarkerWithinBlockWithRequirements()),
        Check(EmptyMarkerWithinBlockWithRequirements),
        "missing required component '$MarkerInBlock'."
    )

    #---------------------------------------------------------------------------------------
    struct MarkerNoBlockRequirements <: Blueprint{Value} end
    @component MarkerNoBlockRequirements requires(MarkerInBlock)

    @sysfails(
        (s + EmptyMarkerWithinBlockWithRequirements()),
        Check(EmptyMarkerWithinBlockWithRequirements),
        "missing required component '$MarkerInBlock'."
    )

    #---------------------------------------------------------------------------------------
    struct ExplicitEmptyLists <: Blueprint{Value} end
    @component ExplicitEmptyLists requires() implies()

    s = System{Value}(ExplicitEmptyLists())
    @test has_component(s, ExplicitEmptyLists)

    #---------------------------------------------------------------------------------------
    # Any expression can be given if it evaluates to expected macro input.
    struct ValueFromExpression <: Blueprint{Value} end
    # Check that the expression is only evaluated once.
    ev_count = [0]
    function value_expression()
        ev_count[1] += 1
        ValueFromExpression
    end
    @component value_expression()

    s = System{Value}(ValueFromExpression())
    @test has_component(s, ValueFromExpression)
    @test ev_count[1] == 1

    struct MarkerFromExpression <: Blueprint{Value} end
    # Check that the expression is only evaluated once.
    ev_count = [0]
    function marker_expression()
        ev_count[1] += 1
        EmptyMarker
    end
    @component MarkerFromExpression implies((marker_expression())())

    s = System{Value}(MarkerFromExpression())
    @test has_component(s, MarkerFromExpression)
    @test has_component(s, EmptyMarker)
    @test ev_count[1] == 1

    # ======================================================================================
    # Invalid invocations.

    # Since they are tested for failures,
    # the following macro calls typically abort halfway through their expansion/execution.
    # To avoid unexpected interactions between subsequent tests,
    # use a new dummy trigram component name for every test.

    #---------------------------------------------------------------------------------------
    # Raw basic misuses.

    @pcompfails((@component), ["Not enough macro input provided. Example usage:\n"])

    @pcompfails((@component a b c d e), ["Too much macro input provided. Example usage:\n"])

    @xcompfails(
        (@component 4 + 5),
        nothing,
        ["Blueprint type: expression does not evaluate to a DataType: :(4 + 5), \
          but to a Int64: 9."]
    )

    @xcompfails(
        (@component NotAtype),
        nothing,
        "Blueprint type: expression does not evaluate: :NotAtype. \
         (See error further down the exception stack.)"
    )

    struct ForgotBaseType end
    @xcompfails(
        (@component ForgotBaseType),
        ForgotBaseType,
        "Not a subtype of '$Blueprint': '$ForgotBaseType'."
    )

    abstract type AbstractBluePrint <: Blueprint{Value} end
    @xcompfails(
        (@component AbstractBluePrint),
        AbstractBluePrint,
        ["Cannot define component from an abstract blueprint type: '$AbstractBluePrint'."]
    )

    struct Eft <: Blueprint{Value} end
    @pcompfails(
        (@component Eft call()),
        "Invalid @component section. Expected `requires(..)` or `implies(..)`, \
         got: :(call())."
    )

    struct Ohk <: Blueprint{Value} end
    @pcompfails(
        (@component Ohk struct NotASection end),
        ["Invalid @component section. Expected `requires(..)` or `implies(..)`, \
          got: :(struct NotASection"],
    )

    #---------------------------------------------------------------------------------------
    # Requires section.

    struct Kpr <: Blueprint{Value} end
    @xcompfails(
        (@component Kpr requires(4 + 5)),
        Kpr,
        "Required component: expression does not evaluate to a DataType: :(4 + 5), \
         but to a Int64: 9."
    )

    struct Maf <: Blueprint{Value} end
    @xcompfails(
        (@component Maf requires(NotAComponent)),
        Maf,
        "Required component: expression does not evaluate: :NotAComponent. \
         (See error further down the exception stack.)"
    )

    struct Rhr <: Blueprint{Value} end
    @xcompfails(
        (@component Rhr requires(EmptyMarker, EmptyMarker)),
        Rhr,
        "Requirement '$EmptyMarker' is specified twice."
    )

    struct Joo <: Blueprint{Value} end
    @xcompfails(
        (@component Joo requires(Int64)),
        Joo,
        "Required component: '$Int64' does not subtype '$Blueprint{$Value}'."
    )

    #---------------------------------------------------------------------------------------
    # Implies section.

    struct Pqc <: Blueprint{Value} end
    @xcompfails(
        (@component Pqc implies(4 + 5)),
        Pqc,
        "Implied blueprint: expression does not evaluate to a DataType: :(4 + 5), \
         but to a Int64: 9."
    )

    struct Rci <: Blueprint{Value} end
    @xcompfails(
        (@component Rci implies(NotAComponent)),
        Rci,
        "Implied blueprint: expression does not evaluate: :NotAComponent. \
         (See error further down the exception stack.)"
    )

    struct Nzu <: Blueprint{Value} end
    @xcompfails(
        (@component Nzu implies(NotAComponent())),
        Nzu,
        "Trivial implied blueprint: expression does not evaluate: :NotAComponent. \
         (See error further down the exception stack.)"
    )

    struct Vbz <: Blueprint{Value} end
    @xcompfails(
        (@component Vbz implies(EmptyMarker, EmptyMarker)),
        Vbz,
        "Implied blueprint '$EmptyMarker' is specified twice."
    )

    struct Iwg <: Blueprint{Value} end
    @xcompfails(
        (@component Iwg implies(EmptyMarker(), EmptyMarker)),
        Iwg,
        "Implied blueprint '$EmptyMarker' is specified twice."
    )

    struct Inm <: Blueprint{Value} end
    @xcompfails(
        (@component Inm implies(Int64)),
        Inm,
        "Implied blueprint: '$Int64' does not subtype '$Blueprint{$Value}'."
    )

    struct Bai <: Blueprint{Value} end
    @xcompfails(
        (@component Bai implies(EmptyMarker) requires(EmptyMarker)),
        Bai,
        "Component is both a requirement and implied: '$EmptyMarker'."
    )

    struct Eil <: Blueprint{Value} end
    @xcompfails(
        (@component Eil implies(EmptyMarker)),
        Eil,
        "No blueprint constructor has been defined \
         to implicitly add '$EmptyMarker' when adding '$Eil' to a system."
    )

    #---------------------------------------------------------------------------------------
    # Guard against inconsistent repetitions.

    struct Tzx <: Blueprint{Value} end
    @pcompfails(
        (@component Tzx requires(Bai) requires(Inm)),
        "The `requires` section is specified twice."
    )

    struct Cok <: Blueprint{Value} end
    @pcompfails(
        (@component Cok implies(Bai) implies(Inm)),
        "The `implies` section is specified twice."
    )

end
end

# ==========================================================================================
module Abstracts
using ..ComponentMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pcompfails, @xcompfails
using Test

const S = System{Value}
comps(s) = sort(collect(components(s)); by = repr)

@testset "Abstract component types requirements." begin

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
    @component B
    @component C
    @component D

    #---------------------------------------------------------------------------------------
    # Basic semantics.

    # Requires abstract.
    struct RequiresAbstractComponent <: Blueprint{Value} end
    @component begin
        RequiresAbstractComponent
        requires(A)
    end
    @sysfails(
        S(RequiresAbstractComponent()),
        Check(RequiresAbstractComponent),
        "missing a required component '$A'."
    )

    # Trivial implied abstract.
    struct ImpliesAbstractComponent <: Blueprint{Value} end
    @xcompfails(
        (@component begin
            ImpliesAbstractComponent
            implies(A())
        end),
        ImpliesAbstractComponent,
        "No trivial blueprint default constructor has been defined \
         to implicitly add '$A' when adding '$ImpliesAbstractComponent' to a system."
    )
    @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    A() = B() # Implicit to B(), say.
    @component ImpliesAbstractComponent implies(A())
    @test comps(S(ImpliesAbstractComponent())) == [B, ImpliesAbstractComponent] # Fixed.
    @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    # Implied abstract with explicit constructor.
    struct ImpliesDefaultConcreteComponent <: Blueprint{Value} end
    A(::ImpliesDefaultConcreteComponent) = C()
    @component begin
        ImpliesDefaultConcreteComponent
        implies(A)
    end
    @test comps(S(ImpliesDefaultConcreteComponent())) ==
          [C, ImpliesDefaultConcreteComponent]
    @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    # Brought abstract.
    struct BroughtAbstractComponent <: Blueprint{Value}
        a::A
    end
    @component BroughtAbstractComponent
    @test comps(S(BroughtAbstractComponent(D()))) == [BroughtAbstractComponent, D]

    #---------------------------------------------------------------------------------------
    # Invocation failures.

    # Guard against double specifications.
    struct Wta <: Blueprint{Value} end
    @component Wta # Once.
    @xcompfails(
        (@component Wta), # Not twice.
        Wta,
        "Blueprint type '$Wta' already marked as a component for '$System{$Value}'."
    )

    # Implicit redundant requires.
    struct Hxl <: Blueprint{Value} end
    @xcompfails(
        (@component Hxl requires(A, B)),
        Hxl,
        "Requirement '$B' is also specified as '$A'."
    )

    struct Ppo <: Blueprint{Value} end
    @xcompfails(
        (@component Ppo requires(B, A)),
        Ppo,
        "Requirement '$B' is also specified as '$A'."
    )

    # Implicit redundant implies.
    struct Zrm <: Blueprint{Value} end
    @xcompfails(
        (@component Zrm implies(A(), B())),
        Zrm,
        "Implied blueprint '$B' is also specified as '$A'."
    )

    struct Vxp <: Blueprint{Value} end
    @xcompfails(
        (@component Vxp implies(B(), A())),
        Vxp,
        "Implied blueprint '$B' is also specified as '$A'."
    )

    struct Ixh <: Blueprint{Value} end
    B(::Ixh) = B()
    @xcompfails(
        (@component Ixh implies(A(), B)),
        Ixh,
        "Implied blueprint '$B' is also specified as '$A'."
    )

    struct Jxi <: Blueprint{Value} end
    A(::Jxi) = B()
    @xcompfails(
        (@component Jxi implies(B(), A)),
        Jxi,
        "Implied blueprint '$B' is also specified as '$A'."
    )

    # Implicit redundant brings.
    struct Ssn <: Blueprint{Value}
        b1::B
        b2::B
    end
    @xcompfails((@component Ssn), Ssn, "Both fields :b1 and :b2 bring component '$B'.")

    struct Qhg <: Blueprint{Value}
        a::A
        b::B
    end
    @xcompfails(
        (@component Qhg),
        Qhg,
        "Fields :b and :a: brought component '$B' is also specified as '$A'."
    )

    # Implicit cross-section redundancy.
    struct Jto <: Blueprint{Value} end
    @xcompfails(
        (@component Jto requires(A) implies(B())),
        Jto,
        "Component is both a requirement (as '$A') and implied: '$B'."
    )

    struct Evt <: Blueprint{Value} end
    @xcompfails(
        (@component Evt requires(B) implies(A())),
        Evt,
        "Component is both a requirement (as '$B') and implied: '$A'."
    )

    struct Qii <: Blueprint{Value} end
    B(::Qii) = B()
    @xcompfails(
        (@component Qii requires(A) implies(B)),
        Qii,
        "Component is both a requirement (as '$A') and implied: '$B'."
    )

    struct Ymy <: Blueprint{Value} end
    A(::Ymy) = B()
    @xcompfails(
        (@component Ymy requires(B) implies(A)),
        Ymy,
        "Component is both a requirement (as '$B') and implied: '$A'."
    )

    struct Web <: Blueprint{Value}
        b::B
    end
    @xcompfails(
        (@component Web requires(A)),
        Web,
        "Component is both a requirement (as '$A') and brought: '$B'."
    )

    struct Spn <: Blueprint{Value}
        a::A
    end
    @xcompfails(
        (@component Spn implies(B())),
        Spn,
        "Component is both implied (as '$B') and brought: '$A'."
    )

    #---------------------------------------------------------------------------------------
    # Requiring/Implying as an abstract component is not implemented yet.

end
end
end
