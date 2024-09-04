module ComponentMacro

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
module Invocations
using ..ComponentMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pcompfails, @xcompfails, @failswith
const F = Framework
using Test

@testset "Invocation variations of @component macro." begin

    # ======================================================================================
    # Valid invocations.

    #---------------------------------------------------------------------------------------
    # Basic, null component.

    @component Eyb{Value}

    # Creation of the singleton type and its instance.
    @test Eyb isa _Eyb
    @test _Eyb <: Component{Value}

    # But there is no blueprint to expand into it.
    @failswith(Eyb(), MethodError)

    #---------------------------------------------------------------------------------------
    # Alternate syntax in a block.

    @component begin
        Iew{Value}
    end
    @test Iew isa _Iew
    @test _Iew <: Component{Value}
    @failswith(Iew(), MethodError)

    #---------------------------------------------------------------------------------------
    # With a basic blueprint.

    # '_b' for the blueprint associated with component `Sem`
    struct Sem_b <: Blueprint{Value} end
    @blueprint Sem_b
    @component Sem{Value} blueprints(b::Sem_b)

    # The blueprint is 'namespaced' within the component singleton.
    @test Sem.b === Sem_b

    # And we can use it to expand into a component.
    s = System{Value}(Sem.b())
    @test has_component(s, Sem)

    #---------------------------------------------------------------------------------------
    # Alternate syntax in a block.

    struct Olk_b <: Blueprint{Value} end
    @blueprint Olk_b
    @component begin
        Olk{Value}
        blueprints(b::Olk_b)
    end

    @test Olk.b === Olk_b
    s = System{Value}(Olk.b())
    @test has_component(s, Olk)

    #---------------------------------------------------------------------------------------
    # Require other component.

    struct Cvh_b <: Blueprint{Value} end
    struct Zjz_b <: Blueprint{Value} end
    @blueprint Cvh_b
    @blueprint Zjz_b

    @component Cvh{Value} blueprints(b::Cvh_b)
    @component Zjz{Value} blueprints(b::Zjz_b) requires(Cvh)

    @test collect(F.requires(Cvh)) == []
    @test collect(F.requires(Zjz)) == [_Cvh => nothing]

    s = System{Value}()
    # Cannot add Zjz without Cvh.
    @sysfails((s + Zjz.b()), Add(MissingRequiredComponent, _Zjz, Cvh, [Zjz_b], nothing))
    s += Cvh.b() # Meet the requirement.
    s += Zjz.b() # Now it's okay.
    @test collect(components(s)) == [Cvh, Zjz]

    #---------------------------------------------------------------------------------------
    # Alternate syntax in blocks.

    struct Dsy_b <: Blueprint{Value} end
    struct Lev_b <: Blueprint{Value} end
    @blueprint Dsy_b
    @blueprint Lev_b

    @component Dsy{Value} blueprints(b::Dsy_b)
    # (alternate syntax)
    @component begin
        Lev{Value}
        blueprints(b::Lev_b)
        requires(_Dsy) # Okay to use component *type* instead.
    end

    @test collect(F.requires(Dsy)) == []
    @test collect(F.requires(Lev)) == [_Dsy => nothing]

    s = System{Value}()
    @sysfails((s + Lev.b()), Add(MissingRequiredComponent, _Lev, Dsy, [Lev_b], nothing))
    s += Dsy.b() + Lev.b()
    @test collect(components(s)) == [Dsy, Lev]

    #---------------------------------------------------------------------------------------
    # Explicit empty lists.

    @component Nzo{Value} blueprints() requires()
    @test fieldnames(_Nzo) == () # No blueprints listed.
    @test collect(F.requires(Nzo)) == [] # No requirements.

    # Test with a constructible one that it does require nothing.
    struct Lwk_b <: Blueprint{Value} end
    @blueprint Lwk_b
    @component Lwk{Value} blueprints(b::Lwk_b) requires()
    s = System{Value}(Lwk.b())
    @test has_component(s, Lwk)

    #---------------------------------------------------------------------------------------
    # Any expression can be given in 'require' if it evaluates to expected macro input.

    struct Tap_b <: Blueprint{Value} end
    struct Dsn_b <: Blueprint{Value} end
    @blueprint Tap_b
    @blueprint Dsn_b

    @component Tap{Value} blueprints(b::Tap_b)

    tap_count = [0] # (check that it's only evaluated once as expected)
    dsn_count = [0]
    function tap_expression()
        tap_count[1] += 1
        Tap
    end
    function dsn_expression()
        dsn_count[1] += 1
        Dsn_b
    end

    # Use arbitrary instead of identifier paths.
    @component Dsn{Value} blueprints(b::dsn_expression()) requires(tap_expression())

    # The requirement works..
    s = System{Value}()
    @sysfails((s + Dsn.b()), Add(MissingRequiredComponent, _Dsn, Tap, [Dsn_b], nothing))
    s += Tap.b() + Dsn.b()
    @test collect(components(s)) == [Tap, Dsn]
    # .. and the expressions have only been evaluated once to this end.
    @test tap_count == [1]
    @test dsn_count == [1]

end

@testset "Invalid @component macro invocations." begin

    #---------------------------------------------------------------------------------------
    # Raw basic misuses.

    @pcompfails((@component), ["Not enough macro input provided. Example usage:\n"])

    @pcompfails((@component a b c d e), ["Too much macro input provided. Example usage:\n"])

    @pcompfails(
        (@component 4 + 5),
        "Expected component `Name{ValueType}` or `Name <: SuperComponent`, \
         got instead: :(4 + 5)."
    )

    # Missing value type.
    @pcompfails(
        (@component Vector),
        "Expected component `Name{ValueType}` or `Name <: SuperComponent`, \
         got instead: :Vector."
    )

    @xcompfails(
        (@component Oan{NotAType}),
        nothing,
        "Evaluating given system value type: \
         expression does not evaluate: :NotAType. \
         (See error further down the exception stack.)"
    )

    @xcompfails(
        (@component Vector{Int64}),
        nothing,
        "Cannot define component 'Vector': name already defined."
    )

    @component Rrn{Value}
    @xcompfails(
        (@component Rrn{Int64}),
        nothing,
        "Cannot define component 'Rrn': name already defined."
    )

    @pcompfails(
        (@component Eft{Value} wrong()),
        "Invalid @component section. Expected `requires(..)` or `blueprints(..)`, \
         got instead: :(wrong())."
    )

    @pcompfails(
        (@component Ohk{Value} struct NotASection end),
        ["Invalid @component section. Expected `requires(..)` or `blueprints(..)`, \
          got instead: :(struct NotASection"],
    )

    #---------------------------------------------------------------------------------------
    # Blueprints section.

    @pcompfails(
        (@component Uvv{Value} blueprints(4 + 5)),
        "Expected `name::Type` to specify blueprint, found instead: :(4 + 5).",
    )

    @xcompfails(
        (@component Uvv{Value} blueprints(b::(4 + 5))),
        :Uvv,
        "Blueprint: expression does not evaluate to a DataType: :(4 + 5), \
         but to a Int64: 9.",
    )

    @xcompfails(
        (@component Uvv{Value} blueprints(b::Int)),
        :Uvv,
        "Blueprint: '$Int64' does not subtype '$Blueprint{$Value}'.",
    )

    # The given blueprint(s) need to target the same type.
    struct Uvv_i <: Blueprint{Int} end
    @blueprint Uvv_i
    @xcompfails(
        (@component Uvv{Value} blueprints(b::Uvv_i)),
        :Uvv,
        "Blueprint: '$Uvv_i' does not subtype '$Blueprint{$Value}', but '$Blueprint{$Int}'.",
    )

    # Guard against redundancy / collisions.
    struct Uvv_b <: Blueprint{Value} end
    @blueprint Uvv_b
    @xcompfails(
        (@component Uvv{Value} blueprints(b::Uvv_b, c::Uvv_b)),
        :Uvv,
        "Base blueprint $Uvv_b bound to both names :b and :c.",
    )

    struct Uvv_c <: Blueprint{Value} end
    @blueprint Uvv_c
    @xcompfails(
        (@component Uvv{Value} blueprints(b::Uvv_b, b::Uvv_c)),
        :Uvv,
        "Base blueprint :b both refers to $Uvv_b and to $Uvv_c.",
    )

    #---------------------------------------------------------------------------------------
    # Requires section.

    @xcompfails(
        (@component Kpr{Value} requires(Undefined)),
        :Kpr,
        "Required component: expression does not evaluate: :Undefined. \
        (See error further down the exception stack.)"
    )

    @xcompfails(
        (@component Kpr{Value} requires(4 + 5)),
        :Kpr,
        "Required component: the given expression does not evaluate \
         to a component for '$Value':\n\
         Expression: :(4 + 5)\n\
         Result: 9 ::$Int"
    )

    @xcompfails(
        (@component Kpr{Value} requires(Int)),
        :Kpr,
        "Required component: the given type does not subtype '<Component{$Value}>':\n\
         Expression: :Int\n\
         Result: $Int ::DataType"
    )

    @component Wdj{Int}
    @xcompfails(
        (@component Odv{Value} requires(Wdj)),
        :Odv,
        "Required component: the given expression does not evaluate \
         to a component for '$Value', but for '$Int':\n\
         Expression: :Wdj\n\
         Result: $Wdj ::<Wdj>"
    )

    # Guard against redundancies.
    abstract type Lpx <: Component{Value} end # (including vertical hierachy checks)
    @component Rhr <: Lpx
    @component Crq{Value}

    @xcompfails(
        (@component Mpz{Value} requires(Crq, Crq)),
        :Mpz,
        "Requirement <Crq> is specified twice."
    )

    @xcompfails(
        (@component Mpz{Value} requires(Lpx, Rhr)),
        :Mpz,
        "Requirement <Rhr> is also specified as <Lpx>."
    )

    @xcompfails(
        (@component Mpz{Value} requires(Rhr, Lpx)),
        :Mpz,
        "Requirement <Rhr> is also specified as <Lpx>."
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

    #  # Component type hierachy.
    #  #
    #  #      A
    #  #    ┌─┼─┐
    #  #    B C D
    #  #
    #  abstract type A <: Blueprint{Value} end
    #  struct B <: A end
    #  struct C <: A end
    #  struct D <: A end
    #  @component B
    #  @component C
    #  @component D

    #---------------------------------------------------------------------------------------
    # Basic semantics.

    #  # Requires abstract.
    #  struct RequiresAbstractComponent <: Blueprint{Value} end
    #  @component begin
    #  RequiresAbstractComponent
    #  requires(A)
    #  end
    #  @sysfails(
    #  S(RequiresAbstractComponent()),
    #  Check(RequiresAbstractComponent),
    #  "missing a required component '$A'."
    #  )

    #  # Trivial implied abstract.
    #  struct ImpliesAbstractComponent <: Blueprint{Value} end
    #  @xcompfails(
    #  (@component begin
    #  ImpliesAbstractComponent
    #  implies(A())
    #  end),
    #  ImpliesAbstractComponent,
    #  "No trivial blueprint default constructor has been defined \
    #  to implicitly add '$A' when adding '$ImpliesAbstractComponent' to a system."
    #  )
    #  @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    #  A() = B() # Implicit to B(), say.
    #  @component ImpliesAbstractComponent implies(A())
    #  @test comps(S(ImpliesAbstractComponent())) == [B, ImpliesAbstractComponent] # Fixed.
    #  @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    #  # Implied abstract with explicit constructor.
    #  struct ImpliesDefaultConcreteComponent <: Blueprint{Value} end
    #  A(::ImpliesDefaultConcreteComponent) = C()
    #  @component begin
    #  ImpliesDefaultConcreteComponent
    #  implies(A)
    #  end
    #  @test comps(S(ImpliesDefaultConcreteComponent())) ==
    #  [C, ImpliesDefaultConcreteComponent]
    #  @test comps(S(D(), ImpliesAbstractComponent())) == [D, ImpliesAbstractComponent]

    #  # Brought abstract.
    #  struct BroughtAbstractComponent <: Blueprint{Value}
    #  a::A
    #  end
    #  @component BroughtAbstractComponent
    #  @test comps(S(BroughtAbstractComponent(D()))) == [BroughtAbstractComponent, D]

    #  #---------------------------------------------------------------------------------------
    #  # Invocation failures.

    #  # Guard against double specifications.
    #  struct Wta <: Blueprint{Value} end
    #  @component Wta # Once.
    #  @xcompfails(
    #  (@component Wta), # Not twice.
    #  Wta,
    #  "Blueprint type '$Wta' already marked as a component for '$System{$Value}'."
    #  )

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

    #  #---------------------------------------------------------------------------------------
    #  # Requiring/Implying as an abstract component is not implemented yet.

end
end
end
