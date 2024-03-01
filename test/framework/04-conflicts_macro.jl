module ConflictsMacro

# The plain value to wrap in a "system" in subsequent tests.
struct Value end
Base.copy(v::Value) = deepcopy(v)
export Value

# Use submodules to not clash marker names.
# ==========================================================================================
module Invocations
using ..ConflictsMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pconffails, @xconffails
using Test

# Generate many small "markers" components just to toy with'em.
for letter in 'A':'Z'
    eval(:(struct $(Symbol(letter)) <: Blueprint{Value} end))
end

@testset "Invocations variations for @conflicts macro." begin

    #---------------------------------------------------------------------------------------
    # Provide enough data for the declaration to be meaningful.
    @pconffails((@conflicts), ["No macro arguments provided. Example usage:"])
    @pconffails(
        (@conflicts A),
        "At least two components are required to declare a conflict not only :A."
    )
    @pconffails(
        (@conflicts(A)),
        "At least two components are required to declare a conflict not only :A."
    )
    @pconffails(
        (@conflicts(A,)),
        "At least two components are required to declare a conflict not only :A."
    )
    @pconffails(
        (@conflicts (A,)), # Watch this subtle semantic difference.
        "At least two components are required to declare a conflict not only :((A,))."
    )
    @pconffails(
        (@conflicts(A => ())),
        "At least two components are required to declare a conflict not only :A."
    )
    @xconffails((@conflicts(A, A)), "Component '$A' cannot conflict with itself.")
    @xconffails(
        (@conflicts(A, Invocations.A)),
        "Component '$A' cannot conflict with itself."
    )

    #---------------------------------------------------------------------------------------
    # No conflicts *a priori*, they are declared by the macro invocation.

    confs(C) = sort(collect(Framework.conflicts(C)); by = repr)
    @test confs(A) == []

    @conflicts(A, B)
    @test confs(A) == [(A, B, nothing)]
    @test confs(B) == [(B, A, nothing)]

    @conflicts C D
    @test confs(C) == [(C, D, nothing)]
    @test confs(D) == [(D, C, nothing)]

    # Guard against non-components types.
    @xconffails(
        (@conflicts(XX, YY)),
        "First conflicting entry: expression does not evaluate: :XX. \
         (See error further down the exception stack.)"
    )

    @xconffails(
        (@conflicts(A, YY)),
        "Conflicting entry: expression does not evaluate: :YY. \
         (See error further down the exception stack.)"
    )

    @xconffails(
        (@conflicts(4 + 5, 6)),
        "First conflicting entry: expression does not evaluate to a $DataType: :(4 + 5), \
         but to a $Int64: 9.",
    )

    @xconffails(
        (@conflicts(A, 6)),
        "Conflicting entry: expression does not evaluate to a $DataType: 6, \
         but to a $Int64: 6.",
    )

    @xconffails(
        (@conflicts(Int64, Float64)),
        "First conflicting entry: not a subtype of '$Blueprint': '$Int64'.",
    )

    @xconffails(
        (@conflicts(A, Float64)), # 'Value' inferred from the first entry.
        "Conflicting entry: '$Float64' does not subtype '$Blueprint{$Value}'.",
    )

    a = 5
    @xconffails(
        (@conflicts(a, a)),
        "First conflicting entry: expression does not evaluate to a $DataType: :a, \
         but to a Int64: 5.",
    )

    @xconffails(
        (@conflicts(A, a)),
        "Conflicting entry: expression does not evaluate to a $DataType: :a, \
         but to a Int64: 5.",
    )

    #---------------------------------------------------------------------------------------
    # Provide a reason for the conflict.

    @conflicts(C, D => (C => "D dislikes C."))
    @test confs(C) == [(C, D, nothing)]
    @test confs(D) == [(D, C, "D dislikes C.")]

    s = System{Value}(A(), C())
    @sysfails(s + D(), Check(D), "conflicts with component '$C': D dislikes C.")

    # Invalid reasons specs.
    @xconffails(
        (@conflicts(E, (4 + 5) => (E => "ok"))),
        "Conflicting entry: expression does not evaluate to a $DataType: :(4 + 5), \
         but to a Int64: 9.",
    )
    @pconffails((@conflicts(E, F => (4 + 5))), "Not a list of conflict reasons: :(4 + 5).")
    @xconffails(
        (@conflicts(E, F => (E => 4 + 5))),
        "Reason message: expression does not evaluate to a String: :(4 + 5), \
         but to a Int64: 9."
    )
    @xconffails(
        (@conflicts(E, F => (4 + 5 => "ok"))),
        "Reason reference: expression does not evaluate to a $DataType: :(4 + 5), \
         but to a Int64: 9."
    )
    @xconffails(
        (@conflicts(E, F => (A => "A dislikes F."))),
        "Conflict reason does not refer to a component listed \
         in the same @conflicts invocation: $A => \"A dislikes F.\"."
    )
    @xconffails(
        (@conflicts(E, F => (F => "F again?"))),
        "Component '$F' cannot conflict with itself."
    )
    @xconffails(
        (@conflicts(E, F => (Invocations.F => "F again?"))),
        "Component '$F' cannot conflict with itself."
    )
    @xconffails(
        (@conflicts(E, F => (B => "B?"))),
        "Conflict reason does not refer to a component \
         listed in the same @conflicts invocation: $B => \"B?\"."
    )

    # Same, but with a list of reasons.
    @xconffails(
        (@conflicts(E, F, G => (F => "ok", E => 4 + 5))),
        "Reason message: expression does not evaluate to a String: :(4 + 5), \
         but to a Int64: 9."
    )
    @xconffails(
        (@conflicts(E, F, G => [F => "ok", 4 + 5 => "message"])),
        "Reason reference: expression does not evaluate to a $DataType: :(4 + 5), \
         but to a Int64: 9."
    )
    @xconffails(
        (@conflicts(E, F, G => (F => "ok", A => "A dislikes F."))),
        "Conflict reason does not refer to a component listed \
         in the same @conflicts invocation: $A => \"A dislikes F.\"."
    )

    #---------------------------------------------------------------------------------------
    # Even if not all reasons are provided, do declare all conflicts as a clique.

    @conflicts(
        U,
        V => [X => "V dislikes X.", U => "V dislikes U."],
        W,
        X => (V => "X dislikes V.", W => "X dislikes W."),
        Y => (X => "Y dislikes X."),
        Z,
    )

    # Conflictual with no description of the reason:
    @test confs(U) == [(U, c, nothing) for c in [V, W, X, Y, Z]]
    @test confs(W) == [(W, c, nothing) for c in [U, V, X, Y, Z]]
    @test confs(Z) == [(Z, c, nothing) for c in [U, V, W, X, Y]]
    # Or with a description:
    @test confs(V) == [
        (V, U, "V dislikes U."),
        (V, W, nothing),
        (V, X, "V dislikes X."),
        (V, Y, nothing),
        (V, Z, nothing),
    ]
    @test confs(X) == [
        (X, U, nothing),
        (X, V, "X dislikes V."),
        (X, W, "X dislikes W."),
        (X, Y, nothing),
        (X, Z, nothing),
    ]
    @test confs(Y) == [
        (Y, U, nothing),
        (Y, V, nothing),
        (Y, W, nothing),
        (Y, X, "Y dislikes X."),
        (Y, Z, nothing),
    ]

    # It is okay to imply the same conflicts again in a new invocation..
    @conflicts(A, U, V => (A => "V dislikes A.")) # (U and V were already known).

    # .. unless it would override the reason already specified.
    @xconffails(
        (@conflicts(B, U, V => (U => "New reason why V dislikes U."))),
        "Component '$V' already declared to conflict with '$U' \
         for the following reason:\n  V dislikes U.",
    )

end
end

# ==========================================================================================
module Abstracts
using ..ConflictsMacro
using EcologicalNetworksDynamics.Framework
using Main: @sysfails, @pconffails, @xconffails
using Test

const S = System{Value}
comps(s) = sort(collect(components(s)); by = repr)

@testset "Abstract component types conflicts." begin

    # Component type hierachy.
    #
    #    A
    #  ┌─┴─┐      G
    #  B ┌─C─┐  ┌─┼─┐
    #  │ │   │  │ │ │
    #  D E   F  H I J
    #
    abstract type A <: Blueprint{Value} end
    abstract type G <: Blueprint{Value} end
    abstract type B <: A end
    abstract type C <: A end
    struct D <: B end
    struct E <: C end
    struct F <: C end
    struct H <: G end
    struct I <: G end
    struct J <: G end
    @component D
    @component E
    @component F
    @component H
    @component I
    @component J

    # Conflict between abstract and concrete component types.
    @conflicts(A, H => (A => "H dislikes A."))
    @test comps(S(D(), I())) == [D, I] #
    @test comps(S(D(), I())) == [D, I] # (allowed combinations)
    @test comps(S(J(), D())) == [D, J] #
    @test comps(S(J(), D())) == [D, J] #
    @sysfails(
        S(D(), H()), # (with an explicit reason)
        Check(H),
        "conflicts with component '$D' (as '$A'): H dislikes A."
    )
    @sysfails(
        S(H(), D()), # (without explicit reason)
        Check(D),
        "conflicts (as '$A') with component '$H'."
    )

    # Conflict between two abstract component types.
    @conflicts(C => (B => "C dislikes B."), B)
    @test comps(S(E(), I())) == [E, I] #
    @test comps(S(F(), I())) == [F, I] # (allowed combinations)
    @test comps(S(J(), E())) == [E, J] #
    @test comps(S(J(), F())) == [F, J] #
    @sysfails(
        S(D(), E()), # (with an explicit reason)
        Check(E),
        "conflicts (as '$C') with component '$D' (as '$B'): C dislikes B."
    )
    @sysfails(
        S(E(), D()), # (without explicit reason)
        Check(D),
        "conflicts (as '$B') with component '$E' (as '$C')."
    )

    # Forbid vertical conflicts.
    @xconffails(
        @conflicts(G, I),
        "Component '$I' cannot conflict with its own supertype '$G'."
    )
    @xconffails(
        @conflicts(I, G),
        "Component '$I' cannot conflict with its own supertype '$G'."
    )

    # Guard against redundant reason specifications.
    @xconffails(
        @conflicts(F, H => (F => "H dislikes F.")),
        "Component '$H' already declared to conflict with '$F' (as '$A') \
         for the following reason:\n  H dislikes A."
    )
    @xconffails(
        @conflicts(D, E => (D => "E dislikes D.")),
        "Component '$E' (as '$C') already declared to conflict with '$D' (as '$B') \
         for the following reason:\n  C dislikes B."
    )

end
end

end
