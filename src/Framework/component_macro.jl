# Convenience macro for defining components.
# TODO: rewrite to remove all blueprint-related aspects.
#
# Invoker defines the component blueprints,
# and possible abstract component supertypes,
# and then calls:
#
#   @component Name requires(components...) blueprints(names...)
#
# HERE: now that the @blueprint macro has been extracted.
#
# Or alternately:
#
#   @component begin
#       Blueprint
#       requires(components...)
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
# so it feels like "subblueprints" or "subcomponents".
# Also, any field subtyping 'Union{Nothing,<:Blueprint}'
# is considered *optionally* embedded depending on the blueprint value.
#
# The components corresponding to brought blueprints
# are automatically be recorded as 'required',
# even if unspecified in the 'required' section.
#
# The code checking macro invocation consistency requires
# that these pre-requisites be specified *prior* to invocation.
macro component(input...)

    # Push resulting generated code to this variable.
    res = quote end
    push_res!(xp) = xp.head == :block ? append!(res.args, xp.args) : push!(res.args, xp)

    # Raise *during expansion* if parsing fails.
    perr(mess) = throw(ItemMacroParseError(:component, __source__, mess))

    # Raise *during execution* if the macro was invoked with inconsistent input.
    # (assuming `NewComponent` generated variable has been set)
    src = Meta.quot(__source__)
    push_res!(
        quote
            NewComponent = nothing # Refined later.
            xerr =
                (mess) -> throw(ItemMacroExecError(:component, NewComponent, $src, mess))
        end,
    )

    # Convenience wrap.
    tovalue(xp, ctx, type) = to_value(__module__, xp, ctx, :xerr, type)
    tocomptype(xp, ctx) = to_component_type(__module__, xp, :ValueType, ctx, :xerr)

    #---------------------------------------------------------------------------------------
    # Parse macro input,
    # while also generating code checking invoker input within invocation context.

    # Unwrap input if given in a block.
    if length(input) == 1 && input[1] isa Expr && input[1].head == :block
        input = rmlines(input[1]).args
    end

    li = length(input)
    if li == 0 || li > 3
        perr(
            "$(li == 0 ? "Not enough" : "Too much") macro input provided. Example usage:\n\
             | @component begin\n\
             |      Blueprint\n\
             |      requires(...)\n\
             |      implies(...)\n\
             | end\n",
        )
    end

    # The first section needs to be a concrete component.
    # Use it to extract the associated underlying expected system value type,
    # checked for consistency against upcoming other specified component.
    blueprint_xp = input[1]
    push_res!(
        quote
            NewComponent = $(tovalue(blueprint_xp, "Blueprint type", DataType))
            NewComponent <: Blueprint ||
                xerr("Not a subtype of '$Blueprint': '$NewComponent'.")
            isabstracttype(NewComponent) && xerr(
                "Cannot define component from an abstract blueprint type: '$NewComponent'.",
            )
            ValueType = system_value_type(NewComponent)

            specified_as_component(NewComponent) &&
                xerr("Blueprint type '$NewComponent' already marked \
                      as a component for '$(System{ValueType})'.")

        end,
    )

    # Next come other optional sections in any order.
    requires_xp = nothing # Evaluates to [(component => reason), ...]
    implies_xp = nothing # Evaluates to [(component, is_trivial), ...]

    for i in input[2:end]

        # Require section: specify necessary components.
        @capture(i, requires(reqs__))
        if !isnothing(reqs)
            isnothing(requires_xp) || perr("The `requires` section is specified twice.")
            requires_xp = :([])
            for req in reqs
                # Set requirement reason to 'nothing' if unspecified.
                @capture(req, comp_ => reason_)
                if isnothing(reason)
                    comp = req
                else
                    reason = tovalue(reason, "Requirement reason", String)
                end
                comp = tocomptype(comp, "Required component")
                req = :($comp => $reason)
                push!(requires_xp.args, req)
            end
            continue
        end

        # Implies section: specify automatically expanded blueprints.
        @capture(i, implies(impls__))
        if !isnothing(impls)
            isnothing(implies_xp) || perr("The `implies` section is specified twice.")
            implies_xp = :([])
            for impl in impls
                @capture(impl, trivial_())
                (xp, flag) = if isnothing(trivial)
                    (tocomptype(impl, "Implied blueprint"), false)
                else
                    (tocomptype(trivial, "Trivial implied blueprint"), true)
                end
                push!(implies_xp.args, :($xp, $flag))
            end
            continue
        end

        perr("Invalid @component section. \
              Expected `requires(..)` or `implies(..)`, \
              got: $(repr(i)).")

    end
    isnothing(requires_xp) && (requires_xp = :([]))
    isnothing(implies_xp) && (implies_xp = :([]))

    # Check that consistent requires/implied component types have been specified.
    push_res!(
        quote

            # Required components.
            reqs = OrderedDict{Component,Reason}()
            for (req, reason) in $requires_xp
                # Triangular-check against redundancies.
                for (already, _) in reqs
                    vertical_guard(
                        req,
                        already,
                        () -> xerr("Requirement '$req' is specified twice."),
                        (sub, sup) ->
                            xerr("Requirement '$sub' is also specified as '$sup'."),
                    )
                end
                reqs[req] = reason
            end

            # Implied blueprints.
            implies = $implies_xp
            impls = OrderedSet{Component}()
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

                # Check against cross-sections specifications.
                for (req, _) in reqs
                    vertical_guard(
                        req,
                        impl,
                        (sub, sup) -> begin
                            as_r = sub === sup ? "" : " (as '$req')"
                            xerr("Component is both a requirement$(as_r) \
                                  and implied: '$impl'.")
                        end,
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
                              when adding '$NewComponent' to a system.")
                    end
                else
                    try
                        which(impl, (NewComponent,))
                    catch
                        xerr("No blueprint constructor has been defined \
                              to implicitly add '$impl' \
                              when adding '$NewComponent' to a system.")
                    end
                end
            end

            # Brings: automatically inferred from the fields.
            brought = OrderedSet{Component}()
            brought_parms = Vector{Tuple{Symbol,Bool}}() # (name, is_optional)
            for (fieldtype, name) in zip(NewComponent.types, fieldnames(NewComponent))

                # Optional if unioned with nothing.
                (bring, is_optional) = if fieldtype isa Union
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
                for (already, (a, _)) in zip(brought, brought_parms)
                    vertical_guard(
                        bring,
                        already,
                        () -> xerr("Both fields $(repr(a)) and $(repr(name)) \
                                    bring component '$bring'."),
                        (sub, sup) -> xerr("Fields $(repr(name)) and $(repr(a)): \
                                            brought component '$sub' is also specified as '$sup'."),
                    )
                end

                # Check against cross-"sections" specifications.
                for (req, _) in reqs
                    vertical_guard(
                        req,
                        bring,
                        (sub, sup) -> begin
                            as_r = sub === sup ? "" : " (as '$req')"
                            xerr("Component is both a requirement$(as_r) \
                                  and brought: '$bring'.")
                        end,
                    )
                end
                for (impl, _) in implies
                    vertical_guard(
                        impl,
                        bring,
                        (sub, sup) -> begin
                            as_i = sub === sup ? "" : " (as '$impl')"
                            xerr("Component is both implied$(as_i) \
                                  and brought: '$bring'.")
                        end,
                    )
                end

                push!(brought, bring)
                push!(brought_parms, (name, is_optional))

            end

            # Automatically require implied and brought components.
            for (impl, _) in implies
                reqs[impl] = "implied."
            end
            for (bring, (_, is_optional)) in zip(brought, brought_parms)
                reqs[bring] = if is_optional
                    "optionally brought."
                else
                    "brought."
                end
            end
        end,
    )

    #---------------------------------------------------------------------------------------
    # At this point, all necessary information should have been parsed and checked,
    # both at expansion time and generated code execution time.
    # The only remaining code to generate work is just the code required
    # for the system to work correctly.

    # Setup the components required.
    push_res!(quote
        Framework.requires(::Type{NewComponent}) = reqs
    end)

    # Setup the blueprints implied.
    push_res!(quote
        function Framework.implies(bp::NewComponent)
            res = []
            for I in impls
                can_imply(bp, I) && push!(res, I)
            end
            res
        end
    end)

    # Setup the blueprints brought.
    push_res!(quote
        function Framework.brings(bp::NewComponent)
            res = []
            for (B, (name, is_optional)) in zip(brought, brought_parms)
                field = getfield(bp, name)
                is_optional && isnothing(field) && continue
                push!(res, B)
            end
            res
        end
    end)

    # Generate trivial implied components constructors for auto-loading.
    # This requires one additional nested level of code generation
    # because the exact list of implied and brought components
    # are only known after macro expansion.
    push_res!(
        quote

            for (impl, trivial) in zip(impls, trivials)
                if trivial
                    eval(quote
                        construct_implied(::Type{$impl}, ::$NewComponent) = $impl()
                    end)
                else
                    eval(
                        quote
                            construct_implied(::Type{$impl}, bp::$NewComponent) = $impl(bp)
                        end,
                    )
                end
            end

            for (bring, (name, _)) in zip(brought, brought_parms)
                eval(quote
                    construct_brought(::Type{$bring}, bp::$NewComponent) = bp.$name
                end)
            end

        end,
    )

    # Legacy record.
    push_res!(quote
        push!(COMPONENTS_SPECIFIED, NewComponent)
    end)

    res
end
export @component

const COMPONENTS_SPECIFIED = Set{Component}()
specified_as_component(c::Component) = c in COMPONENTS_SPECIFIED
