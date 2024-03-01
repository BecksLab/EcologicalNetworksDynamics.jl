module Blueprints

# The plain value to wrap in a "system" in subsequent tests.
struct Value end
Base.copy(v::Value) = deepcopy(v)
export Value

# Use submodules to not clash type names.
# ==========================================================================================
module MacroInvocations
using ..Blueprints
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pbluefails, @xbluefails
using Test
const F = Framework

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
        "Method implied_blueprint_for($MissingImplyFields, Type{<Data>}) unspecified."
    )

    # Define one, but not the other.
    F.implied_blueprint_for(::MissingImplyFields, ::Type{_Data}) = DataBlueprint(5, 8)
    @xbluefails(
        (@blueprint MissingImplyFields),
        MissingImplyFields,
        "Method implied_blueprint_for($MissingImplyFields, Type{<Empty>}) unspecified."
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
        "Both fields :data and :other potentially bring <Data>.",
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

#  # ==========================================================================================
#  module Abstracts
#  using ..BlueprintMacro
#  using EcologicalNetworksDynamics.Framework
#  using Main: @sysfails, @pcompfails, @xcompfails
#  using Test

#  const S = System{Value}
#  comps(s) = sort(collect(components(s)); by = repr)

#  @testset "Abstract component types requirements." begin

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

#  #---------------------------------------------------------------------------------------
#  # Basic semantics.

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

#  end
#  end
end
