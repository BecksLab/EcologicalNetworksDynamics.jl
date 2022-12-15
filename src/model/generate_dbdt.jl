# Generate a minimalistic, absolutely-dedicated dBdt! function
# to hand out to the ODE solver.
# The generated function is only valid for one specific value of `ModelParameters`,
# and must be re-generated any time the parameters change
# and/or the associated network topology.

# The code below works with julia representations of julia code,
# in terms of julia's "symbols" and "expressions".
# The idea is that identifiers within the simple expressions
# explicitly appearing in the program
# will be successively transformed according to replacement rules
# until the whole code in dBdt! is generated.

"""
Construct a copy of the expression with the replacements given in `rep`.

```jldoctest
julia> import BEFWM2: replace

julia> replace(:(a + (b + c / a)), Dict(:a => 5, :b => 8))
:(5 + (8 + c / 5))
```
"""
function replace(xp, rep)
    # Degenerated single occurence case.
    if haskey(rep, xp)
        return rep[xp]
    end
    # Deep-copy with a recursive descent.
    res = Expr(xp.head)
    for a in xp.args
        if haskey(rep, a)
            a = rep[a]
        elseif isa(a, Expr)
            a = replace(a, rep)
        end
        push!(res.args, a)
    end
    res
end

"""
Repeat the given expression into terms of a sum,
successively replacing `indexes` in `term` by elements in (zipped) `lists`.

```jldoctest
julia> import BEFWM2: xp_sum

julia> xp_sum([:i], [[1, 2, 3]], :(u^i)) #  Three terms.
:(u ^ 1 + u ^ 2 + u ^ 3)

julia> xp_sum([:i], [[1]], :(u^i)) #  Single term.
:(u ^ 1)

julia> xp_sum([:i], [[]], :(u^i)) #  No terms.
0

julia> xp_sum([:i, :j], [[:a, :b, :c], [5, 8, 13]], :(j * i)) #  Zipped indices.
:(5a + 8b + 13c)
```
"""
function xp_sum(indexes, lists, term)
    n_terms = min((length(l) for l in lists)...)
    if n_terms == 0
        return 0
    end
    if n_terms == 1
        reps = Dict(index => v for (index, v) in zip(indexes, first(zip(lists...))))
        return replace(term, reps)
    end
    sum = Expr(:call, :+)
    for values in zip(lists...)
        reps = Dict(index => v for (index, v) in zip(indexes, values))
        push!(sum.args, replace(term, reps))
    end
    sum
end

# Recursively visit the expression to modify it once according to the transformation rules.
# The rules are plain symbols corresponding functions identifiers returning expressions.
#  - When appearing as plain identifier like in `1 + symbol + 2`, they are replaced
#    with the expression returned by `symbol(data...)`.
#  - When appearing as function calls like `1 + symbol(expr, expr) + 2`, they are replaced
#    with the expression returned by `symbol(expr, expr)` as one would expect.
# Return false when no modification has been made, so no more expansion step is needed.
function expand!(xp, rules, data)
    modified = false
    for (n, a) in enumerate(xp.args)
        # Simple identifier case.
        if a in rules
            xp.args[n] = eval(a)(data...)
            modified = true
        elseif isa(a, Expr)
            # Call-like identifier(args).
            if a.head == :call && a.args[1] in rules
                xp.args[n] = eval(a)
                modified = true
            else
                modified |= expand!(a, rules, data)
            end
        end
    end
    modified
end

"""
    generate_dbdt(parms::ModelParameters, type)

Produce a specialized julia expression and associated data,
supposed to improve efficiency of subsequent simulations.
The returned expression is typically
[`eval`](https://docs.julialang.org/en/v1/devdocs/eval/)uated
then passed along with the data as a `diff_code_data` argument to [`simulate`](@ref).

There are two possible code generation styles:

  - With `type = :raw`,
    the generated expression is a straightforward translation
    of the underlying differential equations,
    with no loops, no recursive calls, nor heap-allocations:
    only local variables and basic arithmetic is used.
    This makes simulation very efficient,
    but the length of the generated expression
    depends on the number of species interactions.
    When the length becomes high,
    it takes much longer for julia to compile it.
    If it takes forever,
    (typically over `SyntaxtTree.callcount(expression) > 20_000`),
    wait until julia 1.9 ([maybe](https://discourse.julialang.org/t/profiling-compilation-of-a-large-generated-expression/83179))
    or use the alternate style instead.

  - With `type = :compact`,
    the generated expression is a more sophisticated implementation
    of the underlying differential equations,
    involving carefully crafted minimal loops
    and exactly one fixed-size heap-allocated bunch of data,
    reused on every call during simulation.
    This makes the simulation slightly less efficient than the above but,
    as the expression size no longer depends on the number of species interactions,
    there is no limit to using it and speedup simulations.
"""
function generate_dbdt(parms::ModelParameters, type)
    style = Symbol(type)

    # TEMP: Summary of working and convincingly tested implementations.
    resp = typeof(parms.functional_response)
    net = typeof(parms.network)
    function to_test()
        @warn "Automatic generated :$style specialized code for $resp ($net) \
               has not been rigorously tested yet.\n\
               If you are using it for non-trivial simulation, \
               please make sure that the resulting trajectories \
               do match the ones generated with traditional generic code \
               with the same parameters:\n$parms\n\
               If they are, then consider adding that simulation to the packages tests set \
               so this warning can be removed in future upgrades."
    end
    unimplemented() = throw("Automatic generated :$style specialized code for $resp ($net) \
                             is not implemented yet.")
    ok() = nothing
    #! format: off
    Dict(
        (FoodWeb         , :raw    , LinearResponse)       => to_test,
        (FoodWeb         , :raw    , ClassicResponse)      => to_test,
        (FoodWeb         , :raw    , BioenergeticResponse) => to_test,
        (FoodWeb         , :compact, LinearResponse)       => to_test,
        (FoodWeb         , :compact, ClassicResponse)      => to_test,
        (FoodWeb         , :compact, BioenergeticResponse) => to_test,
        (MultiplexNetwork, :raw    , LinearResponse)       => unimplemented,
        (MultiplexNetwork, :raw    , ClassicResponse)      => unimplemented,
        (MultiplexNetwork, :raw    , BioenergeticResponse) => unimplemented,
        (MultiplexNetwork, :compact, LinearResponse)       => unimplemented,
        (MultiplexNetwork, :compact, ClassicResponse)      => unimplemented,
        (MultiplexNetwork, :compact, BioenergeticResponse) => unimplemented,
    )[(net, style, resp)]()
    #! format: on

    if style == :raw
        return generate_dbdt_raw(parms)
    end

    if style == :compact
        return generate_dbdt_compact(parms)
    end

    throw("Unknown code generation style: '$style'.")
end

include("./generate_dbdt_compact.jl")
include("./generate_dbdt_raw.jl")
