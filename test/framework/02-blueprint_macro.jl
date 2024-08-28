module Blueprints

# Testing these macros requires to generate numerous new types
# which are bound to constant julia variables.
# In particular, testing macros for *failure*
# typically result in generated code aborting halway through their expansion/execution
# and make it likely that unexpected interactions occur between subsequent tests
# if the names of generated blueprints/components collide.
# Alleviate this by picking random trigrams for the tests:
#   - `Xyz` as component names
#   - `Xyz_b` as associated blueprint names.

# The plain value to wrap in a "system" in subsequent tests.
struct Value end
Base.copy(v::Value) = deepcopy(v)
export Value

# ==========================================================================================
module MacroInvocations
using ..Blueprints
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pbluefails, @xbluefails
using Test
const F = Framework

@testset "Invocation variations of @blueprint macro." begin

    #---------------------------------------------------------------------------------------
    # Basic use: empty blueprint.
    struct Gdu_b <: Blueprint{Value} end
    @blueprint Gdu_b # (that's all it takes)

    # Works with a component to expand into.
    @component Gdu{Value} blueprints(b::Gdu_b)
    s = System{Value}(Gdu.b())
    @test has_component(s, Gdu)

    #---------------------------------------------------------------------------------------
    # Any expression can be given if it evaluates to expected macro input.

    struct Tap_b <: Blueprint{Value} end

    ev_count = [0] # (check that the expression is only evaluated once)
    function value_expression()
        ev_count[1] += 1
        Tap_b
    end

    @blueprint value_expression()

    # Works as expected.
    @component Tap{Value} blueprints(b::Tap_b)
    @test has_component(System{Value}(Tap.b()), Tap)

    # Only evaluated once.
    @test ev_count == [1]

    # ======================================================================================
    # Invalid invocations.

    #---------------------------------------------------------------------------------------
    # Raw basic misuses.

    @xbluefails(
        (@blueprint 4 + 5),
        nothing,
        "Blueprint type: expression does not evaluate to a DataType: :(4 + 5), \
         but to a Int64: 9.",
    )

    @xbluefails(
        (@blueprint Undefined),
        nothing,
        "Blueprint type: expression does not evaluate: :Undefined. \
         (See error further down the exception stack.)",
    )

    @xbluefails(
        (@blueprint Vector{Int}),
        Vector{Int},
        "Not a subtype of '$Blueprint': 'Vector{$Int}'."
    )

    abstract type Hek <: Blueprint{Value} end
    @xbluefails(
        (@blueprint Hek),
        Hek,
        "Cannot define blueprint from an abstract type: '$Hek'."
    )

    struct Eap <: Blueprint{Value} end
    @blueprint Eap
    @xbluefails(
        (@blueprint Eap),
        Eap,
        "Type '$Eap' already marked as a blueprint for '$System{$Value}'."
    )

end

@testset "Invalid @blueprint macro invocations." begin

    #---------------------------------------------------------------------------------------
    # Basic input guards.

    @pbluefails(
        (@blueprint),
        "Not enough macro input provided. Example usage:\n\
         | @blueprint Name\n"
    )

    @pbluefails(
        (@blueprint a b),
        "Too much macro input provided. Example usage:\n\
         | @blueprint Name\n"
    )

    @xbluefails(
        (@blueprint Undefined),
        nothing,
        "Blueprint type: expression does not evaluate: :Undefined. \
        (See error further down the exception stack.)"
    )

    NotAType = 5
    @xbluefails(
        (@blueprint NotAType),
        nothing,
        "Blueprint type: expression does not evaluate to a DataType: :NotAType, \
         but to a Int64: 5."
    )

    struct NotABlueprint end
    @xbluefails(
        (@blueprint NotABlueprint),
        NotABlueprint,
        "Not a subtype of '$Blueprint': '$NotABlueprint'."
    )

    abstract type Abstract <: Blueprint{Value} end
    @xbluefails(
        (@blueprint Abstract),
        Abstract,
        "Cannot define blueprint from an abstract type: '$Abstract'."
    )

    # Okay with any expression evaluating to a blueprint type.
    struct Correct <: Blueprint{Value} end
    f() = Correct
    @blueprint f()

    # Guard against double specifications.
    struct Twice <: Blueprint{Value} end
    @blueprint Twice
    @xbluefails(
        (@blueprint Twice),
        Twice,
        "Type '$Twice' already marked as a blueprint for '$System{$Value}'.",
    )

    #---------------------------------------------------------------------------------------
    # Check brought fields.

    struct EmptyMarker <: Blueprint{Value} end
    @blueprint EmptyMarker
    @component Empty{Value} blueprints(Empty::EmptyMarker)

    struct DataBlueprint <: Blueprint{Value}
        a::Int64
        b::Int64
    end
    @blueprint DataBlueprint
    @component Data{Value} blueprints(Data::DataBlueprint)

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Forget to specify how to construct implied blueprints.
    struct MissingImplyFields <: Blueprint{Value}
        u::Float64
        v::Float64
        data::Brought(Data)
        empty::Brought(Empty)
    end
    @xbluefails(
        (@blueprint MissingImplyFields),
        MissingImplyFields,
        "Method implied_blueprint_for($MissingImplyFields, Type{<Data>}) unspecified \
         to implicitly bring <Data> from $MissingImplyFields blueprints."
    )

    # Define one, but not the other.
    F.implied_blueprint_for(::MissingImplyFields, ::Type{_Data}) = DataBlueprint(5, 8)
    @xbluefails(
        (@blueprint MissingImplyFields),
        MissingImplyFields,
        "Method implied_blueprint_for($MissingImplyFields, Type{<Empty>}) unspecified \
         to implicitly bring <Empty> from $MissingImplyFields blueprints."
    )
    F.implied_blueprint_for(::MissingImplyFields, ::Type{_Empty}) = Empty()

    # Now it's okay.
    @blueprint MissingImplyFields

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Guard against redundant blueprints.
    struct Qev <: Blueprint{Value}
        data::Brought(Data)
        other::Brought(Data)
    end
    F.implied_blueprint_for(::Qev, ::Type{_Data}) = DataBlueprint(5, 8)
    @xbluefails(
        (@blueprint Qev),
        Qev,
        "Both fields 'data' and 'other' potentially bring <Data>.",
    )

    # Redundancy *can* be detected through abstract component hierarchy.
    abstract type TopComp <: Component{Value} end
    struct Agf <: Blueprint{Value} end
    @blueprint Agf
    @component BottomComp <: TopComp blueprints(Agf::Agf)

    struct Jzd <: Blueprint{Value}
        sup::Brought(TopComp)
        sub::Brought(BottomComp)
    end
    F.implied_blueprint_for(::Jzd, ::Type{TopComp}) = Agf()
    F.implied_blueprint_for(::Jzd, ::Type{_BottomComp}) = Agf()
    @xbluefails(
        (@blueprint Jzd),
        Jzd,
        "Fields 'sub' and 'sup': \
         brought blueprint <BottomComp> \
         is also specified as <TopComp>."
    )

end
end

# ==========================================================================================
module Abstracts
using ..Blueprints
using EcologicalNetworksDynamics.Framework
using Main: @failswith, @sysfails, @pcompfails, @xcompfails, @xbluefails
using Test
const F = Framework

const S = System{Value}
comps(s) = sort(collect(components(s)); by = repr)

@testset "Abstract component types relations." begin

    # Component type hierachy.
    #
    #      A
    #    ┌─┼─┐
    #    B C D
    #
    abstract type A <: Component{Value} end

    # Suffix associated blueprints with -b.
    struct Bb <: Blueprint{Value} end
    struct Cb <: Blueprint{Value} end
    struct Db <: Blueprint{Value} end
    @blueprint Bb
    @blueprint Cb
    @blueprint Db

    @component B <: A blueprints(Bb::Bb)
    @component C <: A blueprints(Cb::Cb)
    @component D <: A blueprints(Db::Db)

    #---------------------------------------------------------------------------------------
    # Basic semantics.

    # Require abstract component.
    struct Ahv_b <: Blueprint{Value} end
    @blueprint Ahv_b
    @component Ahv{Value} blueprints(b::Ahv_b) requires(A)
    # It is an error to attempt to expand with no 'A' component.
    @sysfails(S(Ahv_b()), Add(MissingRequiredComponent, Ahv, A, [Ahv_b], nothing))
    # But any concrete component is good.
    sb = S(Bb(), Ahv_b())
    sc = S(Cb(), Ahv_b())
    sd = S(Db(), Ahv_b())
    @test all(has_component(sb, i) for i in [B, A, Ahv])
    @test all(has_component(sc, i) for i in [C, A, Ahv])
    @test all(has_component(sd, i) for i in [D, A, Ahv])

    # Bring an abstract component from a blueprint.
    struct Wmu_b <: Blueprint{Value}
        a::Brought(A)
    end
    F.implied_blueprint_for(::Wmu_b, ::Type{A}) = Bb() # Any is ok.
    @blueprint Wmu_b
    @component Wmu{Value} blueprints(b::Wmu_b)
    # Not brought.
    s = S(Wmu_b(nothing))
    @test !has_component(s, A)
    # Implied.
    s = S(Wmu_b(A))
    @test has_component(s, A)
    @test has_component(s, B) # (the one actually brought)
    # Embedded.
    s = S(Wmu_b(Bb()))
    @test has_component(s, A)
    @test has_component(s, B) # (the one actually brought)
    # Embedding another is ok..
    s = S(Wmu_b(Cb()))
    @test has_component(s, A) # ← ..because this still holds.
    @test has_component(s, C)

    # Embedding anything else is not ok.
    @failswith(Wmu_b(5), F.InvalidBroughtInput(5, A),)
    struct Btb_b <: Blueprint{Value} end
    @blueprint Btb_b
    @component Btb{Value} blueprints(b::Btb_b)
    @failswith(Wmu_b(Btb), F.InvalidImpliedComponent(_Btb, A),)
    @failswith(Wmu_b(Btb_b()), F.InvalidBroughtBlueprint(Btb_b(), A),)

    # Don't forget to specify default implied constructor.
    struct Ipq_b <: Blueprint{Value}
        a::Brought(A)
    end
    @xbluefails(
        (@blueprint Ipq_b),
        Ipq_b,
        "Method implied_blueprint_for($Ipq_b, Type{<A>}) unspecified \
         to implicitly bring <A> from $Ipq_b blueprints.",
    )

    # Expanding from an abstract component.
    struct Som_b <: Blueprint{Value} end
    F.expands_from(::Som_b) = A
    @blueprint Som_b
    @component Som{Value} blueprints(b::Som_b)
    @test isempty(F.requires(Som)) # The component requires nothing..
    # .. but expansion of this blueprint does.
    @sysfails(S(Som_b()), Add(MissingRequiredComponent, nothing, A, [Som_b], nothing))
    # Any concrete component A enables expansion.
    s = S(Bb(), Som_b())
    @test has_component(s, B) # The prerequisite added: B.
    @test has_component(s, A) # Same B but as an abstract A.
    @test has_component(s, Som) # Thus the expansion success.

    #---------------------------------------------------------------------------------------
    # Invocation failures.

    # HERE: keep fixing.

    #  # Implicit redundant requires.
    #  struct Hxl <: Blueprint{Value} end
    #  @xcompfails(
        #  (@component Hxl requires(A, B)),
        #  Hxl,
        #  "Requirement '$B' is also specified as '$A'."
    #  )

    #  struct Ppo <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component Ppo requires(B, A)),
    #  Ppo,
    #  "Requirement '$B' is also specified as '$A'."
    #  )

    #  # Implicit redundant implies.
    #  struct Zrm <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component Zrm implies(A(), B())),
    #  Zrm,
    #  "Implied blueprint '$B' is also specified as '$A'."
    #  )

    #  struct Vxp <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component Vxp implies(B(), A())),
    #  Vxp,
    #  "Implied blueprint '$B' is also specified as '$A'."
    #  )

    #  struct Ixh <: Blueprint{Value} end
    #  B(::Ixh) = B()
    #  @xcompfails(
    #  (@component Ixh implies(A(), B)),
    #  Ixh,
    #  "Implied blueprint '$B' is also specified as '$A'."
    #  )

    #  struct Jxi <: Blueprint{Value} end
    #  A(::Jxi) = B()
    #  @xcompfails(
    #  (@component Jxi implies(B(), A)),
    #  Jxi,
    #  "Implied blueprint '$B' is also specified as '$A'."
    #  )

    #  # Implicit redundant brings.
    #  struct Ssn <: Blueprint{Value}
    #  b1::B
    #  b2::B
    #  end
    #  @xcompfails((@component Ssn), Ssn, "Both fields :b1 and :b2 bring component '$B'.")

    #  struct Qhg <: Blueprint{Value}
    #  a::A
    #  b::B
    #  end
    #  @xcompfails(
    #  (@component Qhg),
    #  Qhg,
    #  "Fields :b and :a: brought component '$B' is also specified as '$A'."
    #  )

    #  # Implicit cross-section redundancy.
    #  struct Jto <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component Jto requires(A) implies(B())),
    #  Jto,
    #  "Component is both a requirement (as '$A') and implied: '$B'."
    #  )

    #  struct Evt <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component Evt requires(B) implies(A())),
    #  Evt,
    #  "Component is both a requirement (as '$B') and implied: '$A'."
    #  )

    #  struct Qii <: Blueprint{Value} end
    #  B(::Qii) = B()
    #  @xcompfails(
    #  (@component Qii requires(A) implies(B)),
    #  Qii,
    #  "Component is both a requirement (as '$A') and implied: '$B'."
    #  )

    #  struct Ymy <: Blueprint{Value} end
    #  A(::Ymy) = B()
    #  @xcompfails(
    #  (@component Ymy requires(B) implies(A)),
    #  Ymy,
    #  "Component is both a requirement (as '$B') and implied: '$A'."
    #  )

    #  struct Web <: Blueprint{Value}
    #  b::B
    #  end
    #  @xcompfails(
    #  (@component Web requires(A)),
    #  Web,
    #  "Component is both a requirement (as '$A') and brought: '$B'."
    #  )

    #  struct Spn <: Blueprint{Value}
    #  a::A
    #  end
    #  @xcompfails(
    #  (@component Spn implies(B())),
    #  Spn,
    #  "Component is both implied (as '$B') and brought: '$A'."
    #  )

end
end
end
