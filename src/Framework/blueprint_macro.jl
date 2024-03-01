# Convenience macro for defining blueprints.
#
# Invoker defines the blueprint struct,
# (before the corresponding component is actually defined)
# and associated late_check/expand!/etc. methods the way they wish,
# and then calls:
#
#   @blueprint Name
#
# Regarding the blueprint 'brought': make an ergonomic BET.
# Any blueprint field typed with Union{Nothing,Blueprint,CompType}
# is automatically considered 'potential brought'.
# In this case, enforce that, if a blueprint, the value would expand to the given component.
#
#   brought(::Name) = iterator over the fields, skipping 'nothing' values (not brought).
#   implied_blueprint_for(::Name, ::Type{CompType}) = <assumed implemented by macro invoker>
#   # TODO: the above signature is a pain: ease it or generate from the macro?
#
# And for blueprint user convenience, override:
#
#   setproperty!(::Name, field, value)
#
# When given `nothing` as a value, void the field.
# When given a blueprint, check that its component for consistency then make it embedded.
# When given a comptype or a singleton component instance, make it implied.
# When given anything else, query the following for a callable blueprint constructor:
#
#   assignment_to_embedded(::Name, field) = Component
#   # (default, not reified/overrideable yet)
#
# then pass whatever value to this constructor to get this sugar:
#
#   blueprint.field = value  --->  blueprint.field = EmbeddedBlueprintConstructor(value)
#
# Construct field type to be automatically detected as brought blueprints.
Brought(C::CompType{V}) where {V} = Union{Nothing,Blueprint{V},Type{C}}
Brought(c::Component) = Brought(typeof(c))
export Brought

# The code checking macro invocation consistency requires
# that pre-requisites (methods implementations) be specified *prior* to invocation.
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

    #---------------------------------------------------------------------------------------
    # Macro input has become very simple now,
    # although it used to be more complicated with several unordered sections to parse.
    # Keep it flexible for now in case it becomes complicated again.

    # Unwrap input if given in a block.
    if length(input) == 1 && input[1] isa Expr && input[1].head == :block
        input = rmlines(input[1]).args
    end

    li = length(input)
    if li == 0 || li > 1
        perr(
            "$(li == 0 ? "Not enough" : "Too much") macro input provided. Example usage:\n\
             | @blueprint Name\n",
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
            serr(mess) = syserr(ValueType, mess)
        end,
    )

    # No more optional sections then.
    # Should they be needed once again, inspire from @component macro to restore them.

    # Check that consistent brought blueprints types have been specified.
    push_res!(
        quote
            # Brought blueprints/components
            # are automatically inferred from the struct fields.
            broughts = OrderedDict{Symbol,CompType{ValueType}}()
            for (name, fieldtype) in zip(fieldnames(NewBlueprint), NewBlueprint.types)

                fieldtype <:
                Union{Nothing,Type{<:Component{ValueType}},<:Blueprint{ValueType}} ||
                    continue
                f = fieldtype
                # Not sure how union members are supposed to be ordered,
                # or whether the ordering is guaranteed at all.
                # Just extract them all and search the component within them.
                (a, b, c) = (f.a, f.b.a, f.b.b)
                TC, _ = iterate(
                    Iterators.filter(i -> i <: Type{<:Component{ValueType}}, [a, b, c]),
                )
                C, = TC.parameters
                try
                    which(implied_blueprint_for, (NewBlueprint, TC))
                catch
                    xerr("Method $implied_blueprint_for($NewBlueprint, $TC) unspecified.")
                end

                # Triangular-check against redundancies.
                for (a, Already) in broughts
                    vertical_guard(
                        C,
                        Already,
                        () -> xerr("Both fields $(repr(a)) and $(repr(name)) \
                                    potentially bring $C."),
                        (Sub, Sup) -> xerr("Fields '$name' and '$a': \
                                            brought blueprint $Sub \
                                            is also specified as $Sup."),
                    )
                end

                broughts[name] = C
            end
        end,
    )

    #---------------------------------------------------------------------------------------
    # At this point, all necessary information should have been parsed and checked,
    # both at expansion time and generated code execution time.
    # The only remaining task is to generate the code required
    # for the system to work correctly.

    # Setup the blueprints brought.
    push_res!(
        quote
            Framework.brought(b::NewBlueprint) =
                Iterators.map(
                    Iterators.filter(f -> !isnothing(getfield(b, f)), keys(broughts)),
                ) do f
                    f = getfield(b, f)
                    f isa Component ? typeof(f) : f
                end
        end,
    )

    # Protect/enhance field assignement for brought blueprints.
    push_res!(
        quote
            function Base.setproperty!(b::NewBlueprint, prop::Symbol, rhs)
                prop in keys(broughts) || setfield!(b, prop, rhs)
                expected_C = broughts[prop]
                val = if rhs isa Blueprint
                    V = system_value_type(rhs)
                    V == ValueType ||
                        serr("Blueprint cannot be embedded by a blueprint \
                              for System{$ValueType}: $rhs.")
                    C = componentof(rhs)
                    C <: expected_C || serr("Blueprint would expand into $C, \
                                             but the field :$prop of $(typeof(b)) \
                                             is supposed to bring \
                                             $expected_C:\n  $rhs")
                    rhs
                elseif rhs isa Component || rhs isa CompType
                    rhs isa Component && (rhs = typeof(rhs))
                    V = system_value_type(rhs)
                    V == ValueType || serr("Component cannot be implied \
                                            by a blueprint for System{$ValueType}: $rhs.")
                    rhs === expected_C || serr("The field :$prop of $(typeof(b)) \
                                                is supposed to bring $expected_C. \
                                                As such, it cannot imply $rhs instead.")
                    expected_C
                elseif isnothing(rhs)
                    nothing
                else
                    # In any other case, forward to an underlying blueprint constructor.
                    # TODO: make this constructor customizeable depending on the value.
                    cstr =
                        isabstracttype(expected_C) ? expected_C :
                        singleton_instance(expected_C)
                    # This needs to be callable.
                    isempty(methods(cstr)) && serr(
                        "Cannot set brought field from arguments values \
                         because $cstr is not (yet?) callable. \
                         Consider providing a blueprint value instead of $(repr(rhs)).",
                    )
                    args, kwargs = if rhs isa Tuple{<:Tuple,<:NamedTuple}
                        rhs
                    elseif rhs isa Tuple
                        (rhs, (;))
                    elseif rhs isa NamedTuple
                        ((), rhs)
                    else
                        ((rhs,), (;))
                    end
                    bp = cstr(args...; kwargs...)
                    bp <: Blueprint{ValueType} && componentof(bp) isa expected_C ||
                        throw(
                            "Automatic blueprint constructor for brought blueprint assignment \
                             yielded an invalid blueprint. \
                             This is a bug in the components library. \
                             Expected blueprint for $expected_C, \
                             got instead:\n$bp",
                        )
                    bp
                end
                setfield!(b, prop, val)
            end
        end,
    )

    # Enhance display, special-casing brought fields.
    push_res!(
        quote
            Base.show(io::IO, b::NewBlueprint) = display_short(io, b)
            Base.show(io::IO, ::MIME"text/plain", b::NewBlueprint) = display_long(io, b)

            function Framework.display_short(io::IO, bp::NewBlueprint)
                grey = crayon"black"
                reset = crayon"reset"
                C = componentof(bp)
                print(io, "$C:$(nameof(NewBlueprint))(")
                for (i, name) in enumerate(fieldnames(NewBlueprint))
                    i > 1 && print(io, ", ")
                    print(io, "$name: ")
                    field = getfield(bp, name)
                    # Special-case brought fields.
                    if name in keys(broughts)
                        if isnothing(field)
                            print(io, "$grey<$nothing>$reset")
                        elseif field isa CompType{ValueType}
                            print(io, field)
                        elseif field isa Blueprint
                            print(io, "<")
                            display_short(field)
                            print(io, ">")
                        else
                            throw("Unreachable: invalid brought blueprint value. \
                                   This is a bug in the framework.")
                        end
                    else
                        display_blueprint_field_short(io, field)
                    end
                end
                print(io, ")")
            end

            function Framework.display_long(io::IO, bp::NewBlueprint; level = 0)
                grey = crayon"black"
                reset = crayon"reset"
                C = componentof(bp)
                print(io, "blueprint for $C: $(nameof(NewBlueprint)) {")
                preindent = repeat("  ", level)
                level += 1
                indent = repeat("  ", level)
                names = fieldnames(NewBlueprint)
                for name in names
                    field = getfield(bp, name)
                    print(io, "\n$indent$name: ")
                    # Special-case brought fields.
                    if name in keys(broughts)
                        if isnothing(field)
                            print(io, "$grey<no blueprint brought>$reset")
                        elseif field isa CompType{ValueType}
                            print(
                                io,
                                "$grey<implied blueprint for $reset$field$grey>$reset",
                            )
                        elseif field isa Blueprint
                            print(io, "$grey<brought $reset")
                            display_long(io, field; level)
                            print(io, "$grey>$reset")
                        else
                            throw("unreachable: invalid brought blueprint value")
                        end
                    else
                        display_blueprint_field_long(io, field; level)
                    end
                    print(io, ",")
                end
                if !isempty(names)
                    print(io, "\n$preindent")
                end
                print(io, "}")
            end

        end,
    )

    # Legacy record.
    push_res!(quote
        push!(BLUEPRINTS_SPECIFIED, NewBlueprint)
    end)

    # Avoid confusing/leaky return type from macro invocation.
    push_res!(quote
        nothing
    end)

    res
end
export @blueprint

const BLUEPRINTS_SPECIFIED = Set{Type{<:Blueprint}}()
specified_as_blueprint(B::Type{<:Blueprint}) = B in BLUEPRINTS_SPECIFIED

# Stubs for display methods.
function display_short end
function display_long end

# Escape hatch to override in case blueprint field values need special display.
display_blueprint_field_short(io::IO, val) = print(io, val)
display_blueprint_field_long(io::IO, val; level = 0) = print(io, val)
