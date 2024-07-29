# Convenience macro for defining blueprints.
#
# Invoker defines the blueprint struct
# (before the corresponding component is actually defined),
# and associated late_check/expand!/etc. methods the way they wish,
# and then calls:
#
#   @blueprint Name
#
# Regarding the blueprints 'brought': make an ergonomic BET.
# Any blueprint field typed with `Union{Nothing,Blueprint,CompType}`
# is automatically considered 'potential brought': the macro invocation makes it work.
# The following methods are relevant then:
#
#   brought(::Name) = generated iterator over the fields, skipping 'nothing' values.
#   implied_blueprint_for(::Name, ::Type{CompType}) = <assumed implemented by macro invoker>
#
# And for blueprint user convenience, override:
#
#   setproperty!(::Name, field, value)
#
# When given `nothing` as a value, void the field.
# When given a blueprint, check its provided components for consistency then embed.
# When given a comptype or a singleton component instance, make it implied.
# When given anything else, query the following for a callable blueprint constructor:
#
#   constructor_for_embedded(::Name, ::Val{fieldname}) = Component
#   # (default, not reified/overrideable yet)
#
# then pass whatever value to this constructor to get this sugar:
#
#   blueprint.field = value  --->  blueprint.field = EmbeddedBlueprintConstructor(value)
#
# ERGONOMIC BET: This will only work if there is no ambiguity which constructor to call:
#  ake it only work if the blueprint type only provides one component
# and this component singleton instance is callable.

# Dedicated field type to be automatically detected as brought blueprints.
struct BroughtField{C,V} # where C<:CompType{V} (enforce)
    value::Union{Nothing,Blueprint{V},Type{C}}
end
Brought(C::CompType{V}) where {V} = BroughtField{C,V}
Brought(c::Component) = Brought(typeof(c))
componentof(::Type{BroughtField{C,V}}) where {C,V} = C
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

    # The first (and only) section needs to be a concrete blueprint type.
    # Use it to extract the associated underlying expected system value type,
    # checked for consistency against upcoming other (implicitly) specified blueprints.
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

                fieldtype <: BroughtField || continue
                C = componentof(fieldtype)
                TC = Type{C}
                applicable(implied_blueprint_for, (NewBlueprint, TC)) ||
                    xerr("Method $implied_blueprint_for($NewBlueprint, $TC) unspecified.")

                # Triangular-check against redundancies.
                for (a, Already) in broughts
                    vertical_guard(
                        C,
                        Already,
                        () -> xerr("Both fields '$a' and '$name' \
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
    # both at expansion time (within this very macro body code)
    # and generated code execution time
    # (within the code currently being generated although not executed yet).
    # The only remaining code to generate work is just the code required
    # for the system to work correctly.

    # Setup the blueprints brought.
    push_res!(
        quote
            imap = Iterators.map
            ifilter = Iterators.filter
            Framework.brought(b::NewBlueprint) =
                imap(ifilter(!isnothing, imap(f -> getfield(b, f), keys(brought)))) do f
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
                    comps = componentsof(rhs)
                    length(comps) == 1 || serr("Blueprint would expand into $comps, \
                                                but the field :$prop of $(typeof(b)) \
                                                is supposed to only bring $expected_C:\n\
                                                $rhs")
                    C = first(comps)
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
                    comps = componentsof(bp)
                    length(comps) == 1 || throw(
                        "Automatic blueprint constructor fo brought blueprint assignment \
                         yielded a blueprint bringing $comps instead of $expected_C. \
                         This is a bug in the components library.",
                    )
                    C = first(comps)
                    bp <: Blueprint{ValueType} && componentsof(bp) isa expected_C ||
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
                comps = provided_comps_display(bp)
                print(io, "$comps:$(nameof(NewBlueprint))(")
                for (i, name) in enumerate(fieldnames(NewBlueprint))
                    i > 1 && print(io, ", ")
                    print(io, "$name: ")
                    field = getfield(bp, name)
                    # Special-case brought fields.
                    display_blueprint_field_short(io, field)
                end
                print(io, ")")
            end

            function Framework.display_long(io::IO, bp::NewBlueprint; level = 0)
                comps = provided_comps_display(bp)
                print(io, "blueprint for $C: $(nameof(NewBlueprint)) {")
                preindent = repeat("  ", level)
                level += 1
                indent = repeat("  ", level)
                names = fieldnames(NewBlueprint)
                for name in names
                    field = getfield(bp, name)
                    print(io, "\n$indent$name: ")
                    # Special-case brought fields.
                    display_blueprint_field_long(io, field; level)
                    print(io, ",")
                end
                if !isempty(names)
                    print(io, "\n$preindent")
                end
                print(io, "}")
            end

        end,
    )

    # Record to avoid multiple calls to `@blueprint A`.
    push_res!(quote
        Framework.specified_as_blueprint(::Type{NewBlueprint}) = true
    end)

    # Avoid confusing/leaky return type from macro invocation.
    push_res!(quote
        nothing
    end)

    res
end
export @blueprint

specified_as_blueprint(B::Type{<:Blueprint}) = false

# Stubs for display methods.
function display_short end
function display_long end

# Escape hatch to override in case blueprint field values need special display.
display_blueprint_field_short(io::IO, val) = print(io, val)
display_blueprint_field_long(io::IO, val; level = 0) = print(io, val)

# Special-case the single-provided-component case.
function provided_comps_display(bp::Blueprint)
    comps = componentsof(bp)
    if length(comps) == 1
        "$(first(comps))"
    else
        "{$(join(comps, ", "))}"
    end
end

#-------------------------------------------------------------------------------------------
# Protect against constructing invalid brought fields.

# From nothing to not bring anything.
Base.convert(::Type{BroughtField{C,V}}, ::Nothing) where {C,V} = BroughtField{C,V}(nothing)

# From a component type to imply it.
function Base.convert(::Type{BroughtField{C,V}}, ::Type{T}) where {V,C,T}
    T <: C || throw(InvalidImpliedComponent{V}(T, C))
    BroughtField{C,V}(T)
end
# From a component value for convenience.
Base.convert(::Type{BroughtField{C,V}}, c::Component) where {V,C} =
    Base.convert(BroughtField{C,V}, typeof(c))

# From a blueprint to embed it.
function Base.convert(::Type{BroughtField{C,V}}, bp::Blueprint{V}) where {C,V}
    comps = componentsof(bp)
    length(comps) > 1 && throw(InvalidBroughtBlueprint{V}(bp, C))
    first(comps) <: C || throw(InvalidBroughtBlueprint{V}(bp, C))
    BroughtField{C,V}(bp)
end

struct InvalidImpliedComponent{V}
    T::Type
    C::CompType{V}
end

struct InvalidBroughtBlueprint{V}
    b::Blueprint{V}
    C::CompType{V}
end

#-------------------------------------------------------------------------------------------

function display_blueprint_field_short(io::IO, bf::BroughtField)
    grey = crayon"black"
    reset = crayon"reset"
    (; value) = bf
    if isnothing(value)
        print(io, "$grey<$nothing>$reset")
    elseif value isa CompType
        print(io, value)
    elseif value isa Blueprint
        print(io, "<")
        display_short(io, value)
        print(io, ">")
    else
        throw("unreachable: invalid brought blueprint field value: \
               $(repr(value)) ::$(typeof(value))")
    end
end

function display_blueprint_field_long(io::IO, bf::BroughtField; level = 0)
    grey = crayon"black"
    reset = crayon"reset"
    (; value) = bf
    if isnothing(value)
        print(io, "$grey<no blueprint brought>$reset")
    elseif value isa CompType
        print(io, "$grey<implied blueprint for $reset$value$grey>$reset")
    elseif value isa Blueprint
        print(io, "$grey<brought $reset")
        display_long(io, value; level)
        print(io, "$grey>$reset")
    else
        throw("unreachable: invalid brought blueprint field value: \
               $(repr(value)) ::$(typeof(value))")
    end
end

function Base.showerror(io::IO, e::InvalidImpliedComponent{V}) where {V}
    (; T, C) = e
    print(
        io,
        "The field should bring $C, \
         but this component would imply $T instead.",
    )
end

function Base.showerror(io::IO, e::InvalidBroughtBlueprint{V}) where {V}
    (; b, C) = e
    print(
        io,
        "The field should bring $C, \
         but this blueprint would expand into $(provided_comps_display(b)) instead: $b.",
    )
end
