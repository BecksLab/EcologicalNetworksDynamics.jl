# Test the system behaviour when correcty setup by framework users.
module RegularUse

using EcologicalNetworksDynamics.Framework
const F = Framework
export F

# The aggregate value to wrap in a "system" in subsequent tests.
# (loosely inspired from a 'dataframe': indexed collection of vectors of same length.
mutable struct Value
    _n::Int64
    _dict::Dict{Symbol,Any}
    Value() = new(0, Dict())
end
Base.copy(v::Value) = deepcopy(v)
# Willing to enjoy wrapped value properties.
Base.getproperty(v::Value, p::Symbol) = Framework.unchecked_getproperty(v, p)
Base.setproperty!(v::Value, p::Symbol, rhs) = Framework.unchecked_setproperty!(v, p, rhs)
export Value

# ==========================================================================================
# Define basic blueprints/components to work with the above value.

module Basics # Use submodules to not clash component names.
using ..RegularUse
using .F
using Test
using Main: @sysfails, @failswith
export F, Value

#-------------------------------------------------------------------------------------------
# One component/blueprint for the number of lines.
struct NLines <: Blueprint{Value}
    n::Int64
end
F.early_check(nl::NLines) =
    nl.n > 0 || checkfails("Not a positive number of lines: $(nl.n).")
F.expand!(v, nl::NLines) = (v._n = nl.n)
@blueprint NLines
@component Size{Value} blueprints(N::NLines)
export NLines

get_n(v) = v._n
@method get_n depends(Size) read_as(n)

#-------------------------------------------------------------------------------------------
# One component to bring 'a' data.
# Various blueprints bring it, gathered within a module.

module ABlueprints # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

using ..Basics
using EcologicalNetworksDynamics.Framework

struct Uniform <: Blueprint{Value}
    value::Float64
end
F.expand!(v, u::Uniform) = (v._dict[:a] = [u.value for _ in 1:v.n])
@blueprint Uniform

struct Raw <: Blueprint{Value}
    a::Vector{Float64}
end
function F.late_check(v, raw::Raw)
    na = length(raw.a)
    nv = v.n
    na == nv || checkfails("Cannot expand $na 'a' values into $nv lines.")
end
F.expand!(v, r::Raw) = (v._dict[:a] = deepcopy(r.a))
Basics.NLines(r::Raw) = NLines(length(r.a))
@blueprint Raw implies(NLines)

end # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The component gathers all blueprints from the above module.
@component begin
    A{Value}
    requires(Size)
    blueprints(Uniform::ABlueprints.Uniform, Raw::ABlueprints.Raw)
end
get_a(v) = v._dict[:a]
@method get_a depends(A) read_as(a)

#-------------------------------------------------------------------------------------------
# One component to bring 'b' data,
# depending on the 'a' data in that all values must be greater than 'a', say.

module BBlueprints # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

using ..Basics
using EcologicalNetworksDynamics.Framework

struct Uniform <: Blueprint{Value}
    value::Float64
end
F.late_check(v, u::Uniform) =
    maximum(v.a) <= u.value || checkfails("Values 'b' not larger than maximum 'a' values.")
F.expand!(v, u::Uniform) = (v._dict[:b] = [u.value for _ in 1:v.n])
@blueprint Uniform

struct Raw <: Blueprint{Value}
    b::Vector{Float64}
end
function F.late_check(v, raw::Raw)
    nb = length(raw.b)
    nv = v.n
    nb == nv || checkfails("Cannot expand $nb 'a' values into $nv lines.")
    maximum(v.a) <= minimum(raw.b) || checkfails("Values 'b' too small wrt 'a'.")
end
F.expand!(v, r::Raw) = (v._dict[:b] = deepcopy(r.b))
Basics.NLines(r::Raw) = NLines(length(r.b))
@blueprint Raw implies(NLines)

end # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

@component begin
    B{Value}
    requires(Size, A)
    blueprints(Uniform::BBlueprints.Uniform, Raw::BBlueprints.Raw)
end
get_b(v) = v._dict[:b]
@method get_b depends(B) read_as(b)

# One method that uses both components.
get_sum(v) = v.a .+ v.b
@method get_sum depends(A, B) read_as(sum)

#-------------------------------------------------------------------------------------------
# One 'marker' component incompatible with others.

struct SparseMark <: Blueprint{Value} end
@blueprint SparseMark
@component Sparse{Value} blueprints(Mark::SparseMark)
@conflicts(Sparse, Size)

# ==========================================================================================
# Test actual use of the system.

@testset "Basic components/methods." begin

    # Build empty system.
    s = System{Value}()

    # Add component.
    add!(s, NLines(3))

    # Call method.
    @test get_n(s) == 3

    # Read property (equivalent to the above).
    @test s.n == 3

    # Forbid write.
    @sysfails((s.n = 4), Property(n), "This property is read-only.")

    # Cannot add component twice.
    @sysfails(add!(s, NLines(5)), Add(BroughtAlreadyInValue, [NLines]),)

    # Add component requiring previous one from a blueprint.
    t = s + A.Uniform(5)
    @test t.a == [5, 5, 5]

    # Would fail if custom blueprint constraints are not enforced.
    @sysfails(
        s + A.Raw([5, 5]),
        Add(HookCheckFailure, [A.Raw], "Cannot expand 2 'a' values into 3 lines.", true),
    )

    # Blueprints can imply other blueprints.
    e = System{Value}() # Empty.
    s = e + A.Raw([5, 5]) # Automatically bring NLines.
    @test has_component(s, Size)
    @test has_component(s, A)
    @test s.n == 2

    # Display path to failing brought sub-blueprint in case of failure.
    @sysfails(
        e + A.Raw([]),
        Add(
            HookCheckFailure,
            [NLines, true, A.Raw],
            "Not a positive number of lines: 0.",
            false,
        )
    )

    # Cannot add component if requirement is missing.
    @sysfails(
        e + B.Raw([8, 8, 8]),
        Add(MissingRequiredComponent, [B.Raw], A, nothing, false)
    )

    # Cannot use method without the requirements.
    @sysfails(e.sum, Property(sum), "Component 'A' is required to read this property.")

    # Chain summations.
    s = e + NLines(3) + A.Uniform(5) + B.Uniform(8)

    # Use method that requires several components.
    @test s.sum == [13, 13, 13]

    # Cannot add incompatible component.

    @sysfails(
        s + SparseMark(),
        Add(ConflictWithSystemComponent, [SparseMark], Size, nothing),
    )


    #---------------------------------------------------------------------------------------
    # Specify components.

    #  # Setup data.
    #  struct AOne <: Blueprint{Value} end
    #  F.expand!(v, ::AOne) = (v._dict[:a] = 1)
    #  @component AOne

    #  struct BAlgebraic <: Blueprint{Value}
    #  positive::Bool
    #  magnitude::Float64
    #  end
    #  F.expand!(v, b::BAlgebraic) = (v._dict[:b] = b.positive ? b.magnitude : -b.magnitude)
    #  @component BAlgebraic

    #  # Contradictory component.
    #  struct Cannot <: Blueprint{Value} end
    #  @component Cannot
    #  @conflicts(Cannot, AOne)

    #  # Component checking that no value named :a already exists.
    #  struct NoA <: Blueprint{Value} end
    #  function F.check(v, ::NoA)
    #  haskey(v._dict, :a) && checkfails("Cannot add NoA with :a property set.")
    #  end
    #  @component NoA

    #  # Components that require others to work.
    #  struct Summary <: Blueprint{Value}
    #  prefix::String
    #  end
    #  F.expand!(v, s::Summary) = (v._dict[:summary] = s.prefix * ": {a: $(v.a), b: $(v.b)}")
    #  @component begin
    #  Summary
    #  requires(
    #  AOne => "Needs field `.a` to be not nothing.",
    #  BAlgebraic => "Needs field `.b` to be not nothing.",
    #  )
    #  end

    #  # Components that optionally depend on others
    #  # use an additional 'system' argument to query them.
    #  struct Digest <: Blueprint{Value} end
    #  function F.expand!(v, d::Digest, system)
    #  res = ""
    #  if has_component(system, AOne)
    #  res *= "Has A."
    #  end
    #  if has_component(system, BAlgebraic)
    #  res *= "Has B."
    #  end
    #  v._dict[:digest] = res
    #  end
    #  @component Digest

    #  # Component that auto-loads other needed components.
    #  struct TotalPositive <: Blueprint{Value}
    #  magnitude::Float64
    #  end
    #  BAlgebraic(self::TotalPositive) = BAlgebraic(true, self.magnitude)
    #  Summary(::TotalPositive) = Summary("Total positive summary")
    #  @component begin
    #  TotalPositive
    #  # Implication order corresponds to addition order.
    #  implies(AOne(), BAlgebraic, Summary)
    #  end

    #  # Component that brings order "embedded" component.
    #  mutable struct ABPowerSum <: Blueprint{Value}
    #  a::AOne # Always bring.
    #  b::Union{BAlgebraic,Nothing} # Optionally bring.
    #  pow::Int64
    #  # Don't bring b if zero.
    #  ABPowerSum(b, pow) = new(AOne(), b != 0 ? BAlgebraic(true, b) : nothing, pow)
    #  end
    #  F.expand!(v, ps::ABPowerSum) = (v._dict[:ps] = (v.a + v.b)^ps.pow)
    #  @component ABPowerSum

    #  #---------------------------------------------------------------------------------------
    #  # Specify methods.

    #  # Basic read/write accesses.
    #  get_a(v) = v._dict[:a]
    #  get_b(v) = v._dict[:b]
    #  get_digest(v) = v._dict[:digest]
    #  get_power_sum(v) = v._dict[:ps]
    #  set_b!(v, b) = (v._dict[:b] = b)
    #  get_sign(v) = (v.b >= 0 ? +1 : -1)
    #  get_magnitude(v) = abs(v.b)
    #  @method get_a depends(AOne) read_as(a)
    #  @method get_b depends(BAlgebraic) read_as(b)
    #  @method set_b! depends(BAlgebraic) write_as(b)
    #  @method get_sign depends(BAlgebraic) read_as(sign)
    #  @method get_magnitude depends(BAlgebraic) read_as(mag)
    #  @method get_digest depends(Digest) read_as(digest)
    #  @method get_power_sum depends(ABPowerSum) read_as(ps)

    #  set_sign!(v::Value, b::Bool) =
    #  if b
    #  v.b = v.mag # <- Use properties there thanks to unchecked_[gs]etproperty(!).
    #  else
    #  v.b = -v.mag
    #  end
    #  @method begin
    #  set_sign!
    #  write_as(sign)
    #  depends(BAlgebraic) # (order of sections is flexible)
    #  end

    #  get_summary(v) = v._dict[:summary]
    #  @method get_summary depends(Summary) read_as(summary, sm)

    #  #---------------------------------------------------------------------------------------
    #  # Use the system.

    #  s = System{Value}()

    #  # Miss components to use method and properties.
    #  @test blueprints(s) == Set()
    #  @test components(s) == Set()
    #  @test properties(s) == Dict()
    #  @sysfails(get_a(s), Method(get_a), "Requires component '$AOne'.")
    #  @sysfails(s.a, Property(a), "Component '$AOne' is required to read this property.")

    #  # Add component.
    #  add!(s, AOne())

    #  # Now the properties can be used.
    #  @test get_a(s) == 1
    #  @test s.a == 1 # Convenience property access.

    #  @test blueprints(s) == Set([AOne()])
    #  @test components(s) == Set([AOne])
    #  @test properties(s) == Dict(:a => false)

    #  @sysfails((s.a = 2), Property(a), "This property is read-only.")

    #  # Cannot add component if some required components are missing.
    #  @sysfails(
    #  add!(s, Summary("first summary attempt")),
    #  Check(Summary),
    #  "missing required component '$BAlgebraic': \
    #  Needs field `.b` to be not nothing.",
    #  )
    #  # Or if the check does not pass.
    #  @sysfails(add!(s, NoA()), Check(NoA), "Cannot add NoA with :a property set.",)

    #  # One more component unlocks other methods and properties.
    #  add!(s, BAlgebraic(false, 5))
    #  @test (get_b(s), get_sign(s), get_magnitude(s)) == (-5, -1, 5)
    #  @test (s.b, s.sign, s.mag) == (-5, -1, 5) #  Convenience property accesses.
    #  set_sign!(s, true)
    #  @test s.b == 5
    #  s.sign = false # Writable property.
    #  @test s.b == -5
    #  @failswith((s.sign = "not a boolean"), MethodError)

    #  @test blueprints(s) == Set([AOne(), BAlgebraic(false, 5)])
    #  @test components(s) == Set([AOne, BAlgebraic])
    #  @test properties(s) == Dict(:a => false, :b => true, :sign => true, :mag => false)

    #  # Now the higher-level component can be added.
    #  add!(s, Summary("second summary attempt"))
    #  @test s._value._dict[:summary] ==
    #  s.summary ==
    #  s.sm == # Aliases.
    #  "second summary attempt: {a: 1, b: -5.0}"

    #  # Cannot add conflicting components.
    #  @sysfails(add!(s, Cannot()), Check(Cannot), "conflicts with component '$AOne'.",)

    #  # Clone/fork the system by copying it any time.
    #  init = System{Value}()
    #  s = copy(init)
    #  @test blueprints(s) == Set()
    #  @test components(s) == Set()
    #  @test properties(s) == Dict()

    #  # Check that the original system is always empty.
    #  function test_empty(i)
    #  @test isempty(blueprints(i))
    #  @sysfails(get_a(init), Method(get_a), "Requires component '$AOne'.")
    #  @sysfails(
    #  init.a,
    #  Property(a),
    #  "Component '$AOne' is required to read this property."
    #  )
    #  end
    #  test_empty(init)

    #  # Optional dependency arguments.
    #  s = copy(init)
    #  add!(s, Digest())
    #  @test s.digest == ""
    #  test_empty(init)

    #  s = copy(init) + AOne() + Digest()
    #  @test s.digest == "Has A."
    #  test_empty(init)

    #  s = copy(init) + AOne() + BAlgebraic(true, 5) + Digest()
    #  @test s.digest == "Has A.Has B."
    #  test_empty(init)

    #  # "Implied" components are automatically added.
    #  s = copy(init)
    #  add!(s, TotalPositive(9))
    #  @test (s.a, s.b, s.sm) == (1, 9, "Total positive summary: {a: 1, b: 9.0}")
    #  # Only if needed.
    #  s = copy(init)
    #  s += BAlgebraic(true, 33) # Already there.
    #  add!(s, TotalPositive(9)) # Still okay, but value given is ignored in favour of the existing one.
    #  @test (s.a, s.b, s.sm) == (1, 33, "Total positive summary: {a: 1, b: 33.0}")
    #  test_empty(init)

    #  # "Brought" components are also automatically added, but they need to be *not* there.
    #  s = copy(init)
    #  pw = ABPowerSum(77, 2)
    #  add!(s, pw)
    #  @test (s.a, s.b, s.ps) == (1, 77, (1 + 77)^2)
    #  s = copy(init)
    #  s += AOne() # Already there.
    #  @sysfails(
    #  add!(s, pw), # Not okay.
    #  Check(ABPowerSum),
    #  "blueprint also brings '$AOne', which is already in the system."
    #  )
    #  test_empty(init)
    #  # In this case, it is okay to just not bring it.
    #  s = copy(init) + BAlgebraic(true, 88)
    #  pw.b = nothing # Opt-out from bringing it.
    #  add!(s, pw)
    #  @test (s.a, s.b, s.ps) == (1, 88, (1 + 88)^2)

    #  # Use the + operator to add components without altering the original system.
    #  s = init + AOne()
    #  @test s.a == 1
    #  test_empty(init)

    #  # Implied components already there are not added once more.
    #  s += TotalPositive(44)
    #  @test s.b == 44
    #  test_empty(init)

    #  # Sum components together to chain operators.
    #  s = init + AOne()
    #  s += BAlgebraic(false, 5) + Summary("summed") # <- (here)
    #  @test blueprints(s) == Set([AOne(), BAlgebraic(false, 5), Summary("summed")])
    #  @test components(s) == Set([AOne, BAlgebraic, Summary])
    #  test_empty(init)

end
end
end
