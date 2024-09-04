module Blueprints

using EcologicalNetworksDynamics.Framework

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
struct Value
    d::Dict{Symbol,Any}
    Value() = new(Dict())
end
Base.copy(v::Value) = deepcopy(v)
Base.getproperty(s::Framework.System{Value}, name::Symbol) =
    name in fieldnames(System) ? getfield(s, name) : s._value.d[name]
export Value

# ==========================================================================================
module MacroInvocations
using ..Blueprints
using EcologicalNetworksDynamics.Framework
using Main: @failswith, @sysfails, @pbluefails, @xbluefails
using Test
using Crayons
const F = Framework

const S = System{Value}
comps(s) = collect(components(s))

@testset "Invocation variations of @blueprint macro." begin

    # Basic use: empty blueprint.
    struct Gdu_b <: Blueprint{Value} end
    @blueprint Gdu_b # (that's all it takes)

    # Works with a component to expand into.
    @component Gdu{Value} blueprints(b::Gdu_b)
    s = System{Value}(Gdu.b())
    @test has_component(s, Gdu)

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

end

@testset "Invalid @blueprint macro invocations." begin

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
        (@blueprint Cpf),
        nothing,
        "Blueprint type: expression does not evaluate: :Cpf. \
        (See error further down the exception stack.)"
    )

    Zmw_b = 5
    @xbluefails(
        (@blueprint Zmw_b),
        nothing,
        "Blueprint type: expression does not evaluate to a DataType: :Zmw_b, \
         but to a $Int: 5."
    )

    @xbluefails(
        (@blueprint 4 + 5),
        nothing,
        "Blueprint type: expression does not evaluate to a DataType: :(4 + 5), \
         but to a $Int: 9.",
    )

    @xbluefails(
        (@blueprint Vector{Int}),
        Vector{Int},
        "Not a subtype of '$Blueprint': 'Vector{$Int}'."
    )

    struct Xgi end
    @xbluefails((@blueprint Xgi), Xgi, "Not a subtype of '$Blueprint': '$Xgi'.")

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

@testset "Brought fields." begin

    #---------------------------------------------------------------------------------------
    # Definition.

    # Empty blueprint to be brought.
    struct Xhu_b <: Blueprint{Value} end
    @blueprint Xhu_b
    @component Xhu{Value} blueprints(b::Xhu_b)

    # Blueprint with data to be brought.
    struct Ejp_b <: Blueprint{Value}
        u::Int64
        v::Int64
    end
    function F.expand!(v, ejp::Ejp_b)
        v.d[:u] = ejp.u
        v.d[:v] = ejp.v
    end
    @blueprint Ejp_b
    @component Ejp{Value} blueprints(b::Ejp_b)

    # Forget to specify how to construct implied blueprints.
    mutable struct Bdz_b <: Blueprint{Value}
        x::Float64
        y::Float64
        xhu::Brought(Xhu)
        ejp::Brought(Ejp)
    end
    F.implied_blueprint_for(::Bdz_b, ::Type{_Xhu}) = Xhu.b() # Regular method signature.
    F.implied_blueprint_for(::Bdz_b, ::_Ejp) = Ejp.b(5, 8) # Convenience method signature.
    @blueprint Bdz_b
    @component Bdz{Value} blueprints(b::Bdz_b)

    #---------------------------------------------------------------------------------------
    # Use.

    # Bring nothing.
    bdz = Bdz_b(1, 2, nothing, nothing)
    @test comps(S(bdz)) == [Bdz]
    @test comps(S(Xhu.b(), bdz)) == [Xhu, Bdz]
    s = S(Xhu.b(), Ejp.b(1, 2), bdz)
    @test comps(s) == [Xhu, Ejp, Bdz]
    @test (s.u, s.v) == (1, 2)

    # Imply component.
    s = S(Bdz_b(1, 2, nothing, Ejp))
    @test comps(s) == [Ejp, Bdz]
    @test (s.u, s.v) == (5, 8) # Default ones.

    # Only bring the ones missing.
    #    already here                  implied
    #     vvvvvvvvvvv                   vvv
    s = S(Ejp.b(4, 5), Bdz_b(1, 2, Xhu, Ejp))
    @test comps(s) == [Ejp, Xhu, Bdz]
    @test (s.u, s.v) == (4, 5) # (not the implied one)

    # Embed blueprints.
    s = S(Bdz_b(1, 2, Xhu.b(), Ejp.b(15, 30)))
    @test comps(s) == [Xhu, Ejp, Bdz]
    @test (s.u, s.v) == (15, 30)

    # It's an error to embed into a system when it's already there.
    @sysfails(
        S(Xhu.b(), Bdz_b(1, 2, Xhu.b(), Ejp.b(15, 30))),
        Add(BroughtAlreadyInValue, Xhu, [Xhu_b, false, Bdz_b]),
    )

    # Same tests, but from a blueprint modified on the fly.
    bdz = Bdz_b(1, 2, nothing, nothing)
    # Imply.
    bdz.ejp = Ejp
    s = S(bdz)
    @test comps(s) == [Ejp, Bdz]
    @test (s.u, s.v) == (5, 8)
    # Only bring the ones missing.
    bdz.xhu = Xhu
    s = S(Ejp.b(4, 5), bdz)
    @test comps(s) == [Ejp, Xhu, Bdz]
    @test (s.u, s.v) == (4, 5) # (not the implied one)
    # Embed.
    bdz.ejp = Ejp.b(15, 30)
    s = S(bdz)
    @test comps(s) == [Xhu, Ejp, Bdz]
    @test (s.u, s.v) == (15, 30)

    # Embed using implicit blueprint construction.
    (::typeof(Ejp))(u, v) = Ejp.b(u, v)

    # As field assignments.
    bdz.ejp = (15, 30)
    s = S(bdz)
    @test comps(s) == [Xhu, Ejp, Bdz]
    @test (s.u, s.v) == (15, 30)

    # As constructor arguments.
    bdz = Bdz_b(1, 2, nothing, (15, 30))
    s = S(bdz)
    @test comps(s) == [Ejp, Bdz]
    @test (s.u, s.v) == (15, 30)

    # HERE: the working versions.

end

@testset "Invalid brought fields use." begin

    @failswith(Brought(5), MethodError)
    @failswith(Brought(Int), MethodError)
    @failswith(Brought(Vector{Int}), MethodError)
    @failswith(Brought(Vector), MethodError)
    @failswith(Brought(F.Component), MethodError)
    struct Amg_b <: Blueprint{Value} end
    @blueprint Amg_b
    @failswith(Brought(Amg_b), MethodError)

    #---------------------------------------------------------------------------------------
    # Implied blueprint constructors.

    # Forgot to define it.
    struct Ihb_b <: Blueprint{Value}
        x::Float64
        y::Float64
        xhu::Brought(Xhu)
        ejp::Brought(Ejp)
    end
    @xbluefails(
        (@blueprint Ihb_b),
        Ihb_b,
        "Method implied_blueprint_for($Ihb_b, <Xhu>) unspecified \
         to implicitly bring <Xhu> from $Ihb_b blueprints."
    )

    # Define one, but not the other.
    F.implied_blueprint_for(::Ihb_b, ::Type{_Xhu}) = Xhu.b() # Regular method signature.
    @xbluefails(
        (@blueprint Ihb_b),
        Ihb_b,
        "Method implied_blueprint_for($Ihb_b, <Ejp>) unspecified \
         to implicitly bring <Ejp> from $Ihb_b blueprints."
    )
    F.implied_blueprint_for(::Ihb_b, ::_Ejp) = Ejp.b(5, 8) # Convenience method signature.

    # Now it's okay.
    @blueprint Ihb_b

    # Can't define both the regular *and* convenience methods.
    struct Ntz_b <: Blueprint{Value}
        xhu::Brought(Xhu)
    end
    F.implied_blueprint_for(::Ntz_b, ::_Xhu) = Xhu.b()
    F.implied_blueprint_for(::Ntz_b, ::Type{_Xhu}) = Xhu.b()
    @xbluefails(
        (@blueprint Ntz_b),
        Ntz_b,
        "Ambiguity: the two following methods have been defined:\n  \
           $(F.implied_blueprint_for)(::$Ntz_b, ::<Xhu>)\n  \
           $(F.implied_blueprint_for)(::$Ntz_b, ::Type{<Xhu>})\n\
         Consider removing either one."
    )

    #---------------------------------------------------------------------------------------
    # Guard against redundant blueprints.
    struct Qev_b <: Blueprint{Value}
        data::Brought(Ejp)
        other::Brought(Ejp)
    end
    F.implied_blueprint_for(::Qev_b, ::_Ejp) = Ejp.b(5, 8)
    @xbluefails(
        (@blueprint Qev_b),
        Qev_b,
        "Both fields 'data' and 'other' potentially bring <Ejp>.",
    )

    # Redundancy is guarded through abstract component hierarchy.
    abstract type TopComp <: Component{Value} end
    struct Agf_b <: Blueprint{Value} end
    @blueprint Agf_b
    @component BottomComp <: TopComp blueprints(b::Agf_b)

    struct Jzd_b <: Blueprint{Value}
        sup::Brought(TopComp)
        sub::Brought(BottomComp)
    end
    F.implied_blueprint_for(::Jzd_b, ::TopComp) = Agf.b()
    F.implied_blueprint_for(::Jzd_b, ::_BottomComp) = Agf.b()
    @xbluefails(
        (@blueprint Jzd_b),
        Jzd_b,
        "Fields 'sub' and 'sup': \
         brought blueprint <BottomComp> \
         is also specified as <TopComp>."
    )

    #---------------------------------------------------------------------------------------
    # Implicit brought blueprints constructor.

    # Can't call if undefined.
    struct Opv_b <: Blueprint{Value} end
    @blueprint Opv_b
    @component Opv{Value} blueprints(b::Opv_b)
    mutable struct Twt_b <: Blueprint{Value}
        opv::Brought(Opv)
    end
    F.implied_blueprint_for(::Twt_b, ::_Opv) = Opv.b()
    @blueprint Twt_b
    @component Twt{Value} blueprints(b::Twt_b)
    twt = Twt_b(nothing)

    bcf(m, rhs) = F.BroughtConvertFailure(_Opv, m, rhs)
    baf(m, rhs) = F.BroughtAssignFailure(Twt_b, :opv, bcf(m, rhs))

    # Check both failure on constructor and on field assignment.
    erm = "'$Opv' is not (yet?) callable. \
           Consider providing a blueprint value instead."
    @failswith(Twt_b(()), bcf(erm, ()))
    @failswith((twt.opv = ()), baf(erm, ()))

    # Must construct a consistent blueprint.
    constructed = nothing
    # (change ↑ freely to test without triggering 'WARNING: Method definition overwritten')
    (::typeof(Opv))() = constructed
    red, res = (crayon"bold red", crayon"reset")
    bug = "\n$(red)This is a bug in the components library.$res"

    constructed = 5
    erm = "Implicit blueprint constructor did not yield a blueprint, but: 5 ::$Int.$bug"
    @failswith(Twt_b(()), bcf(erm, ()))
    @failswith((twt.opv = ()), baf(erm, ()))

    struct Yfi_b <: Blueprint{Int} end
    constructed = Yfi_b()
    erm = "Implicit blueprint constructor did not yield a blueprint for '$Value', \
           but for '$Int': $Yfi_b().$bug"
    @failswith(Twt_b(()), bcf(erm, ()))
    @failswith((twt.opv = ()), baf(erm, ()))

    struct Sxo_b <: Blueprint{Value} end
    @blueprint Sxo_b
    @component Iej{Value}
    @component Axl{Value}
    F.componentsof(::Sxo_b) = [Iej, Axl]
    constructed = Sxo_b()
    erm = "Implicit blueprint constructor yielded instead \
           a blueprint for: $([Iej, Axl]).$bug"
    @failswith(Twt_b(()), bcf(erm, ()))
    @failswith((twt.opv = ()), baf(erm, ()))

    struct Dpt_b <: Blueprint{Value} end
    @blueprint Dpt_b
    @component Dpt{Value} blueprints(b::Dpt_b)
    constructed = Dpt_b()
    erm = "Implicit blueprint constructor yielded instead a blueprint for: <Dpt>.$bug"
    @failswith(Twt_b(()), bcf(erm, ()))
    @failswith((twt.opv = ()), baf(erm, ()))

    # HERE: the failing versions.

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
        "Method implied_blueprint_for($Ipq_b, <A>) unspecified \
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
