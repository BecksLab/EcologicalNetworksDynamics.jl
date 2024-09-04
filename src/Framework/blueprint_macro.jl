# Convenience macro for defining a new blueprint.
#
# Invoker defines the blueprint struct
# (before the corresponding components are actually defined),
# and associated late_check/expand!/etc. methods the way they wish,
# and then calls:
#
#   @blueprint Name
#
# to record their type as a blueprint.
#
# Regarding the blueprints 'brought': make an ergonomic BET.
# Any blueprint field typed with `BroughtField`
# is automatically considered 'potential brought':
# the macro invocation makes it work out of the box.
# The following methods are relevant then:
#
#   # Generated:
#   brought(::Blueprint) = iterator over the brought fields, skipping 'nothing' values.
#
#   # Invoker-defined:
#   implied_blueprint_for(::Blueprint, ::Type{CompType}) = ...
#   <XOR> implied_blueprint_for(::Blueprint, ::CompType) = ... # (for convenience)
#
# And for blueprint user convenience, the generated code also overrides:
#
#   setproperty!(::Blueprint, field, value)
#
# with something comfortable:
#   - When given `nothing` as a value, void the field.
#   - When given a blueprint, check its provided components for consistency then *embed*.
#   - When given a comptype or a singleton component instance, make it *implied*.
#   - When given anything else, query the following for a callable blueprint constructor:
#
#     constructor_for_embedded(::Blueprint, ::Val{fieldname}) = Component
#     # (defaults to the provided component if single, not reified/overrideable yet)
#
# Then pass whatever value to this constructor to get this sugar:
#
#   blueprint.field = value  --->  blueprint.field = EmbeddedBlueprintConstructor(value)
#
# ERGONOMIC BET: This will only work if there is no ambiguity which constructor to call:
# make it only work if the component singleton instance brought by the field is callable,
# as this means there is an unambiguous default blueprint to be constructed.

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
    blueprint_macro(__module__, __source__, input...)
end
export @blueprint

# Extract function to ease debugging with Revise.
function blueprint_macro(__module__, __source__, input...)

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
            convenience_methods = Bool[]
            for (name, fieldtype) in zip(fieldnames(NewBlueprint), NewBlueprint.types)

                fieldtype <: BroughtField || continue
                C = componentof(fieldtype)
                # Check whether either the specialized method XOR its convenience alias
                # have been defined.
                sp = hasmethod(implied_blueprint_for, Tuple{NewBlueprint,Type{C}})
                conv = hasmethod(implied_blueprint_for, Tuple{NewBlueprint,C})
                (conv || sp) ||
                    xerr("Method $implied_blueprint_for($NewBlueprint, $C) unspecified \
                          to implicitly bring $C from $NewBlueprint blueprints.")
                (conv && sp) &&
                    xerr("Ambiguity: the two following methods have been defined:\n  \
                          $implied_blueprint_for(::$NewBlueprint, ::$C)\n  \
                          $implied_blueprint_for(::$NewBlueprint, ::$Type{$C})\n\
                          Consider removing either one.")

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
                push!(convenience_methods, conv)
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

    # In case the convenience `implied_blueprint_for` has been defined,
    # forward the proper calls to it.
    push_res!(
        quote
            for (C, conv) in zip(values(broughts), convenience_methods)
                if conv
                    Framework.implied_blueprint_for(b::NewBlueprint, C::Type{C}) =
                        implied_blueprint_for(b, singleton_instance(C))
                end
            end
        end,
    )

    # Setup the blueprints brought.
    push_res!(
        quote
            imap = Iterators.map
            ifilter = Iterators.filter
            Framework.brought(b::NewBlueprint) =
                imap(
                    ifilter(!isnothing, imap(f -> getfield(b, f).value, keys(broughts))),
                ) do f
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
                ferr(m) = throw(
                    BroughtAssignFailure{ValueType}(NewBlueprint, prop, expected_C, m, rhs),
                )
                val = if rhs isa Blueprint
                    V = system_value_type(rhs)
                    V == ValueType || ferr("Expected a RHS blueprint for $ValueType.\n\
                                            Got instead a blueprint for: $V.")
                    comps = componentsof(rhs)
                    length(comps) == 1 ||
                        ferr("Blueprint would instead expand into $comps.")
                    C = first(comps)
                    C <: expected_C || ferr("Blueprint would instead expand into $C.")
                    rhs
                elseif rhs isa Component || rhs isa CompType
                    rhs isa Component && (rhs = typeof(rhs))
                    V = system_value_type(rhs)
                    V == ValueType || ferr("Expected a RHS component for $ValueType.\n\
                                            Got instead a component for: $V.")
                    rhs === expected_C || ferr("Value would imply instead: $rhs.")
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
                    isempty(methods(cstr)) && ferr("'$cstr' is not (yet?) callable. \
                                                    Consider providing a \
                                                    blueprint value instead.")
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
                    # It is a bug in the component library (introduced by framework users)
                    # if the implicit constructor yields a wrong value.
                    function bug(m)
                        red, res = (crayon"bold red", crayon"reset")
                        ferr("Implicit blueprint constructor $m\n\
                              $(red)This is a bug in the components library.$res")
                    end
                    bp isa Blueprint || bug("did not yield a blueprint, \
                                             but: $(repr(bp)) ::$(typeof(bp)).")
                    V = system_value_type(bp)
                    V == ValueType || bug(
                        "did not yield a blueprint for '$ValueType', but for '$V': $bp.",
                    )
                    comps = componentsof(bp)
                    length(comps) == 1 ||
                        bug("yielded instead a blueprint for: $comps.")
                    C = first(comps)
                    C == expected_C || bug("yielded instead a blueprint for: $C.")
                    bp
                end
                setfield!(b, prop, BroughtField{expected_C,ValueType}(val))
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
                print(io, "blueprint for $comps: $(nameof(NewBlueprint)) {")
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
# Error when assigning to brought blueprint fields.
struct BroughtAssignFailure{V}
    BlueprintType::Type{<:Blueprint{V}}
    fieldname::Symbol
    BroughtComponent::CompType{V}
    message::String
    rhs::Any
end

function Base.showerror(io::IO, e::BroughtAssignFailure)
    (; BlueprintType, fieldname, BroughtComponent, message, rhs) = e
    print(
        io,
        "Failed to assign to field :$fieldname of '$BlueprintType' \
         supposed to bring component $BroughtComponent:\n$message\n\
         RHS was: $(repr(rhs)) ::$(typeof(rhs))",
    )
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

# From anything else to disallow.
Base.convert(::Type{BroughtField{C,V}}, i::Any) where {C,V} =
    throw(InvalidBroughtInput(i, C))

struct InvalidImpliedComponent{V}
    T::Type
    C::CompType{V}
end

struct InvalidBroughtBlueprint{V}
    b::Blueprint{V}
    C::CompType{V}
end

struct InvalidBroughtInput{V}
    i::Any
    C::CompType{V}
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

function Base.showerror(io::IO, e::InvalidBroughtInput{V}) where {V}
    (; i, C) = e
    print(
        io,
        "The field should bring $C, \
         but a blueprint for this component cannot be constructed \
         from: $(repr(i)) ::$(typeof(i)).",
    )
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
