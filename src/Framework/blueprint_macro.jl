# Convenience macro for defining blueprints.
#
# Invoker defines the blueprint struct,
# (before the corresponding component is actually defined)
# and associated late_check/expand!/etc. methods the way they wish,
# and then calls:
#
#   @blueprint Name implies(blueprints...)
#
# Or alternately:
#
#   @blueprint begin
#       Name
#       implies(blueprints...)
#   end
#
# The blueprint 'implied' are either trivial and specified as `Implied()`
# in which case the following method is generated:
#
#   construct_implied(::Typeof{Implied}, ::Blueprint) = Implied()
#
# Or they are nontrivial and specified as `Implied`:
#
#   construct_implied(::Typeof{Implied}, b::Blueprint) = Implied(b)
#
# and then invoker is responsible for having defined:
#
#   Implied(::Blueprint) = ...
#
# Regarding the blueprints 'embedded': make an ergonomic BET:
# any blueprint field subtyping 'Blueprint' is considered embedded,
# so it feels like "sub-blueprints".
# Also, any field subtyping 'Union{Nothing,<:Blueprint}'
# is considered *optionally* embedded depending on the blueprint value.
#
# The code checking macro invocation consistency requires
# that these pre-requisites be specified *prior* to invocation.
macro blueprint(input...)

    # Push resulting generated code to this variable.
    res = quote end
    push_res!(xp) = xp.head == :block ? append!(res.args, xp.args) : push!(res.args, xp)

    # Raise *during expansion* if parsing fails.
    perr(mess) = throw(ItemMacroParseError(:blueprint, __source__, mess))

    # Raise *during execution* if the macro was invoked with inconsistent input.
    # (assuming `NewBlueprint` generated variable has been set)
    src = Meta.quot(__source__)
    push_res!(
        quote
            NewBlueprint = nothing # Refined later.
            xerr =
                (mess) -> throw(ItemMacroExecError(:blueprint, NewBlueprint, $src, mess))
        end,
    )

    # Convenience wrap.
    tovalue(xp, ctx, type) = to_value(__module__, xp, ctx, :xerr, type)
    tobptype(xp, ctx) = to_blueprint_type(__module__, xp, :ValueType, ctx, :xerr)

    #---------------------------------------------------------------------------------------
    # Parse macro input,
    # while also generating code checking invoker input within invocation context.

    # Unwrap input if given in a block.
    if length(input) == 1 && input[1] isa Expr && input[1].head == :block
        input = rmlines(input[1]).args
    end

    li = length(input)
    if li == 0 || li > 2
        perr(
            "$(li == 0 ? "Not enough" : "Too much") macro input provided. Example usage:\n\
             | @blueprint begin\n\
             |      Name\n\
             |      implies(...)\n\
             | end\n",
        )
    end

    # The first section needs to be a concrete blueprint type.
    # Use it to extract the associated underlying expected system value type,
    # checked for consistency against upcoming other specified blueprints.
    blueprint_xp = input[1]
    push_res!(
        quote
            NewBlueprint = $(tovalue(blueprint_xp, "Blueprint type", DataType))
            NewBlueprint <: Blueprint ||
                xerr("Not a subtype of '$Blueprint': '$NewBlueprint'.")
            isabstracttype(NewBlueprint) &&
                xerr("Cannot define blueprint from an abstract type: '$NewBlueprint'.")
            ValueType = system_value_type(NewBlueprint)
            specified_as_blueprint(NewBlueprint) &&
                xerr("Type '$NewBlueprint' already marked \
                      as a blueprint for '$(System{ValueType})'.")
        end,
    )

    # Next come other optional sections in any order.
    # (only one, but there used to be more, so keep room for extending again)
    implies_xp = nothing # Evaluates to [(blueprint_type, is_trivial), ...]

    for i in input[2:end]

        # Implies section: specify automatically expanded blueprints.
        @capture(i, implies(impls__))
        if !isnothing(impls)
            isnothing(implies_xp) || perr("The `implies` section is specified twice.")
            implies_xp = :([])
            for impl in impls
                @capture(impl, trivial_())
                (xp, flag) = if isnothing(trivial)
                    (tobptype(impl, "Implied blueprint"), false)
                else
                    (tobptype(trivial, "Trivial implied blueprint"), true)
                end
                push!(implies_xp.args, :($xp, $flag))
            end
            continue
        end

        perr("Invalid @blueprint section. \
              Expected `implies(..)`, \
              got: $(repr(i)).")

    end
    isnothing(implies_xp) && (implies_xp = :([]))

    # Check that consistent brought blueprints types have been specified.
    push_res!(
        quote

            # Implied blueprints.
            implies = $implies_xp
            impls = OrderedSet{Type{<:Blueprint}}()
            trivials = Vector{Bool}()
            for (impl, trivial) in implies

                # Triangular-check against redundancies.
                for already in impls
                    vertical_guard(
                        impl,
                        already,
                        () -> xerr("Implied blueprint '$impl' is specified twice."),
                        (sub, sup) ->
                            xerr("Implied blueprint '$sub' is also specified as '$sup'."),
                    )
                end

                push!(impls, impl)
                push!(trivials, trivial)
            end

            # Check that the required constructors have been setup.
            for (impl, trivial) in implies
                if trivial
                    try
                        which(impl, ())
                    catch
                        xerr("No trivial blueprint default constructor has been defined \
                              to implicitly add '$impl' \
                              when adding '$NewBlueprint' to a system.")
                    end
                else
                    try
                        which(impl, (NewBlueprint,))
                    catch
                        xerr("No blueprint constructor has been defined \
                              to implicitly add '$impl' \
                              when adding '$NewBlueprint' to a system.")
                    end
                end
            end

            # Embedding: automatically inferred from the fields.
            embedded = OrderedSet{Type{<:Blueprint}}()
            embedded_parms = Vector{Tuple{Symbol,Bool}}() # (name, is_optional)
            for (fieldtype, name) in zip(NewBlueprint.types, fieldnames(NewBlueprint))

                # Optional if unioned with nothing.
                (embed, is_optional) = if fieldtype isa Union
                    if fieldtype.a === Nothing && fieldtype.b <: Blueprint{ValueType}
                        (fieldtype.b, true)
                    elseif fieldtype.b === Nothing && fieldtype.a <: Blueprint{ValueType}
                        (fieldtype.a, true)
                    else
                        continue
                    end
                elseif fieldtype <: Blueprint{ValueType}
                    (fieldtype, false)
                else
                    continue
                end

                # Triangular-check against redundancies.
                for (already, (a, _)) in zip(embedded, embedded_parms)
                    vertical_guard(
                        embed,
                        already,
                        () -> xerr("Both fields $(repr(a)) and $(repr(name)) \
                                    bring blueprint '$embed'."),
                        (sub, sup) -> xerr("Fields $(repr(name)) and $(repr(a)): \
                                            embedded blueprint '$sub' \
                                            is also specified as '$sup'."),
                    )
                end

                # Check against cross-"sections" specifications.
                for (impl, _) in implies
                    vertical_guard(
                        impl,
                        embed,
                        (sub, sup) -> begin
                            as_i = sub === sup ? "" : " (as '$impl')"
                            xerr("Blueprint is both implied$(as_i) \
                                  and embedded: '$embed'.")
                        end,
                    )
                end

                push!(embedded, embed)
                push!(embedded_parms, (name, is_optional))

            end
            embedded = [e for e in embedded]
        end,
    )

    #---------------------------------------------------------------------------------------
    # At this point, all necessary information should have been parsed and checked,
    # both at expansion time and generated code execution time.
    # The only remaining code to generate work is just the code required
    # for the system to work correctly.

    # Setup the blueprints implied.
    push_res!(quote
        # Iterate on hygienic variable not to leak a reference to it.
        Framework.max_implies(bp::NewBlueprint) = Iterators.map(identity, impls)
    end)

    # Setup the blueprints embedded.
    push_res!(
        quote
            for (B, (name, is_optional)) in zip(embedded, embedded_parms)
                Framework.eval(
                    quote
                        can_embed(b::$NewBlueprint, ::Type{$B}) =
                            !isnothing(b.$name)
                    end,
                )
            end
            Framework.max_embeds(bp::NewBlueprint) = Iterators.map(identity, embedded)
        end,
    )

    # Generate trivial implied blueprint constructors for auto-loading.
    # This requires one additional nested level of code generation
    # because the exact list of implied and embedded blueprints
    # are only known after macro expansion.
    push_res!(
        quote

            for (I, trivial) in zip(impls, trivials)
                if trivial
                    Framework.eval(quote
                        construct_implied(::Type{$I}, ::$NewBlueprint) = $I()
                    end)
                else
                    Framework.eval(quote
                        construct_implied(::Type{$I}, bp::$NewBlueprint) = $I(bp)
                    end)
                end
            end

            for (bring, (name, _)) in zip(embedded, embedded_parms)
                Framework.eval(quote
                    construct_brought(::Type{$bring}, bp::$NewBlueprint) = bp.$name
                end)
            end

        end,
    )

    # Legacy record.
    push_res!(quote
        push!(BLUEPRINTS_SPECIFIED, NewBlueprint)
    end)

    res
end
export @blueprint

const BLUEPRINTS_SPECIFIED = Set{Type{<:Blueprint}}()
specified_as_blueprint(B::Type{<:Blueprint}) = B in BLUEPRINTS_SPECIFIED
