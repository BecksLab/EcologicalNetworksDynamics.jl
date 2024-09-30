# Convenience macro for defining a new blueprint.
#
# Invoker defines the blueprint struct
# (before the corresponding components are actually defined),
# and associated late_check/expand!/etc. methods the way they wish,
# and then calls:
#
#   @blueprint Name "short string answering 'expandable from'"
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
    value::Union{Nothing,Blueprint{V},Type{<:C}}
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
    if li == 0 || li > 2
        perr(
            "$(li == 0 ? "Not enough" : "Too much") macro input provided. Example usage:\n\
             | @blueprint Name \"short description\"\n",
        )
    end

    # The first section needs to be a concrete blueprint type.
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
                      as a blueprint for systems of '$ValueType'.")
            serr(mess) = syserr(ValueType, mess)
        end,
    )

    # Extract possible short description line.
    # TODO: test.
    if length(input) > 1
        shortline_xp = input[2]
        push_res!(
            quote
                shortline = $(tovalue(shortline_xp, "Blueprint short description", String))
            end,
        )
    else
        push_res!(quote
            shortline = nothing
        end)
    end

    # No more sophisticated sections then.
    # Should they be needed once again, inspire from @component macro to restore them.

    # Check that consistent brought blueprints types have been specified.
    push_res!(
        quote
            # Brought blueprints/components
            # are automatically inferred from the struct fields.
            broughts = OrderedDict{Symbol,CompType{ValueType}}()
            convenience_methods = Bool[]
            abstract_implied = Bool[]
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

                # The above does *not* check that the method
                # has been specialized for every possible component type subtyping C.
                # This will need to be checked at runtime,
                # but raise this flag if C is abstract
                # to define a neat error fallback in case it's not.
                abs = isabstracttype(C)

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
                push!(abstract_implied, abs)
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

    push_res!(
        quote
            for (C, conv, abs) in
                zip(values(broughts), convenience_methods, abstract_implied)
                # In case the convenience `implied_blueprint_for` has been defined,
                # forward the proper calls to it.
                if conv
                    Framework.implied_blueprint_for(b::NewBlueprint, C::Type{C}) =
                        implied_blueprint_for(b, singleton_instance(C))
                end
                # In case the brought component type is abstract,
                # define a falllback method in case the components lib
                # provided no way of implying a particular subtype of it.
                # TODO: find a way to raise this error earlier
                # during field assignment or construction.
                if abs
                    function Framework.implied_blueprint_for(
                        b::NewBlueprint,
                        Sub::Type{<:C},
                    )
                        err() = UnimplementedImpliedMethod{ValueType}(NewBlueprint, C, Sub)
                        isabstracttype(Sub) && throw(err())
                        try
                            # The convenience method may have been implemented instead.
                            implied_blueprint_for(b, singleton_instance(Sub))
                        catch e
                            e isa Base.MethodError && rethrow(err())
                            rethrow(e)
                        end
                    end
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
                C = broughts[prop]
                # Defer all checking to conversion methods.
                bf = try
                    Base.convert(BroughtField{C,ValueType}, rhs)
                catch e
                    e isa BroughtConvertFailure && # Additional context available.
                        rethrow(BroughtAssignFailure(NewBlueprint, prop, e))
                    rethrow(e)
                end
                setfield!(b, prop, bf)
            end
        end,
    )

    # Enhance display, special-casing brought fields.
    push_res!(
        quote
            Base.show(io::IO, b::NewBlueprint) = display_short(io, b)
            Base.show(io::IO, ::MIME"text/plain", b::NewBlueprint) = display_long(io, b, 0)

            function Framework.display_short(io::IO, bp::NewBlueprint)
                comps = provided_comps_display(bp)
                print(io, "$comps:$(nameof(NewBlueprint))(")
                for (i, name) in enumerate(fieldnames(NewBlueprint))
                    i > 1 && print(io, ", ")
                    print(io, "$name: ")
                    display_blueprint_field_short(io, bp, Val(name))
                end
                print(io, ")")
            end

            function Framework.display_long(io::IO, bp::NewBlueprint, level)
                comps = provided_comps_display(bp)
                print(io, "blueprint for $comps: $(nameof(NewBlueprint)) {")
                preindent = repeat("  ", level)
                level += 1
                indent = repeat("  ", level)
                names = fieldnames(NewBlueprint)
                for name in names
                    print(io, "\n$indent$name: ")
                    display_blueprint_field_long(io, bp, Val(name), level)
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
        if !isnothing(shortline)
            Framework.shortline(io, ::Type{NewBlueprint}) = print(io, shortline)
        end
    end)

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

#-------------------------------------------------------------------------------------------
# Minor stubs for the macro to work.

specified_as_blueprint(B::Type{<:Blueprint}) = false

# Stubs for display methods.
function display_short end
function display_long end

# Special-case the single-provided-component case.
function provided_comps_display(bp::Blueprint)
    comps = componentsof(bp)
    if length(comps) == 1
        "$(first(comps))"
    else
        "{$(join(comps, ", "))}"
    end
end

# ==========================================================================================
# Protect against constructing invalid brought fields.
# These checks are either run when doing `host.field = ..` or `Host(..)`.

# From nothing to not bring anything.
Base.convert(::Type{BroughtField{C,V}}, ::Nothing) where {C,V} = BroughtField{C,V}(nothing)

#-------------------------------------------------------------------------------------------
# From a component type to imply it.

function Base.convert(
    ::Type{BroughtField{eC,eV}}, # ('expected C', 'expected V')
    aC::CompType{aV}; # ('actual C', 'actual V')
    input = aC,
) where {eV,eC,aV}
    err(m) = throw(BroughtConvertFailure(eC, m, input))
    aV === eV || err("The input would not imply a component for '$eV', but for '$aV'.")
    aC <: eC || err("The input would instead imply $aC.")
    # TODO: How to check whether `implied_blueprint_for` has been defined for aC here?
    # Context is missing because 'NewBlueprintType' is unknown.
    BroughtField{eC,eV}(aC)
end

# From a component value for convenience.
Base.convert(::Type{BroughtField{C,V}}, c::Component) where {V,C} =
    Base.convert(BroughtField{C,V}, typeof(c); input = c)

#-------------------------------------------------------------------------------------------
# From a blueprint to embed it.

function Base.convert(::Type{BroughtField{eC,eV}}, bp::Blueprint{aV}) where {eC,eV,aV}
    err(m) = throw(BroughtConvertFailure(eC, m, bp))
    aV === eV || err("The input does not embed a blueprint for '$eV', but for '$aV'.")
    comps = componentsof(bp)
    length(comps) == 1 || err("Blueprint would instead expand into [$(join(comps, ", "))].")
    aC = first(comps)
    aC <: eC || err("Blueprint would instead expand into $aC.")
    BroughtField{eC,eV}(bp)
end

#-------------------------------------------------------------------------------------------
# From arguments to embed with a call to implicit constructor.

function Base.convert(BF::Type{BroughtField{C,V}}, input::Any) where {C,V}
    BF(implicit_constructor_for(C, V, (input,), (;), input))
end

function Base.convert(BF::Type{BroughtField{C,V}}, args::Tuple) where {C,V}
    BF(implicit_constructor_for(C, V, args, (;), args))
end

function Base.convert(BF::Type{BroughtField{C,V}}, kwargs::NamedTuple) where {C,V}
    BF(implicit_constructor_for(C, V, (), kwargs, kwargs))
end

function Base.convert(BF::Type{BroughtField{C,V}}, akw::Tuple{Tuple,NamedTuple}) where {C,V}
    args, kwargs = akw
    BF(implicit_constructor_for(C, V, args, kwargs, akw))
end

#-------------------------------------------------------------------------------------------
# Checked call to implicit constructor, supposed to yield a consistent blueprint.
function implicit_constructor_for(
    expected_C::CompType,
    ValueType::DataType,
    args::Tuple,
    kwargs::NamedTuple,
    rhs::Any,
)
    bcf(m) = BroughtConvertFailure{ValueType}(expected_C, m, rhs)
    err(m) = throw(bcf(m))
    # TODO: make this constructor customizeable depending on the value.
    cstr = isabstracttype(expected_C) ? expected_C : singleton_instance(expected_C)
    # This needs to be callable.
    isempty(methods(cstr)) && err("'$cstr' is not (yet?) callable. \
                                    Consider providing a \
                                    blueprint value instead.")
    bp = try
        cstr(args...; kwargs...)
    catch e
        if e isa Base.MethodError
            akw = join(args, ", ")
            if !isempty(kwargs)
                akw *=
                    "; " * join(
                        # Wow.. is there anything more idiomatic? ^ ^"
                        Iterators.map(
                            pair -> "$(pair[1]) = $(pair[2])",
                            zip(keys(kwargs), values(kwargs)),
                        ),
                        ", ",
                    )
            end
            throw(bcf("No method matching $cstr($akw). \
                       (See further down the stacktrace.)"))
        end
        rethrow(e)
    end

    # It is a bug in the component library (introduced by framework users)
    # if the implicit constructor yields a wrong value.
    function bug(m)
        red, res = (crayon"bold red", crayon"reset")
        err("Implicit blueprint constructor $m\n\
             $(red)This is a bug in the components library.$res")
    end
    bp isa Blueprint || bug("did not yield a blueprint, \
                             but: $(repr(bp)) ::$(typeof(bp)).")
    V = system_value_type(bp)
    V == ValueType || bug("did not yield a blueprint for '$ValueType', but for '$V': $bp.")
    comps = componentsof(bp)
    length(comps) == 1 || bug("yielded instead a blueprint for: [$(join(comps, ", "))].")
    C = first(comps)
    C <: expected_C || bug("yielded instead a blueprint for: $C.")
    bp
end

#-------------------------------------------------------------------------------------------
# Errors associated to the above checks.

# Error when implicitly using default constructor
# to convert arbitrary input to a brought field.
struct BroughtConvertFailure{V}
    BroughtComponent::CompType{V}
    message::String
    rhs::Any
end

# Specialize error when it occurs in the context
# of a field assignment on the host blueprint.
struct BroughtAssignFailure{V}
    HostBlueprint::Type{<:Blueprint{V}}
    fieldname::Symbol
    fail::BroughtConvertFailure{V}
end

struct UnimplementedImpliedMethod{V}
    HostBlueprint::Type{<:Blueprint{V}}
    BroughtSuperType::CompType{V}
    ImpliedSubType::CompType{V} # Subtypes the above.
end

function Base.showerror(io::IO, e::BroughtConvertFailure)
    (; BroughtComponent, message, rhs) = e
    print(
        io,
        "Failed to convert input \
         to a brought blueprint for $BroughtComponent:\n$message\n\
         Input was: $(repr(rhs)) ::$(typeof(rhs))",
    )
end

function Base.showerror(io::IO, e::BroughtAssignFailure)
    (; HostBlueprint, fieldname, fail) = e
    (; BroughtComponent, message, rhs) = fail
    print(
        io,
        "Failed to assign to field :$fieldname of '$HostBlueprint' \
         supposed to bring component $BroughtComponent:\n$message\n\
         RHS was: $(repr(rhs)) ::$(typeof(rhs))",
    )
end

function Base.showerror(io::IO, e::UnimplementedImpliedMethod{V}) where {V}
    red = crayon"red"
    res = crayon"reset"
    (; HostBlueprint, BroughtSuperType, ImpliedSubType) = e
    print(
        io,
        "A method has been specified to implicitly bring component $BroughtSuperType \
         from '$HostBlueprint' blueprints, \
         but no method is specialized to implicitly bring its subtype $ImpliedSubType.\n\
         $(red)This is a bug in the components library.$res",
    )
end

# ==========================================================================================
#  Display.

# Escape hatches to override in case blueprint field values need special display.
function display_blueprint_field_short(io::IO, bp::Blueprint, ::Val{name}) where {name}
    show(io, getfield(bp, name))
end

function display_blueprint_field_long(
    io::IO,
    bp::Blueprint,
    ::Val{name},
    level,
) where {name}
    display_blueprint_field_long(io, bp, Val(name))
end

# Ignore level by default,
# in a way that makes it possible to also specialize ignoring level.
function display_blueprint_field_long(io::IO, bp::Blueprint, ::Val{name}) where {name}
    show(io, MIME("text/plain"), getfield(bp, name))
end

# Special-casing brought fields.
function Base.show(io::IO, ::Type{<:BroughtField{C,V}}) where {C,V}
    grey = crayon"black"
    reset = crayon"reset"
    print(io, "$grey<brought field type for $reset$C$grey>$reset")
end
Base.show(io::IO, bf::BroughtField) = display_blueprint_field_short(io, bf)
Base.show(io::IO, ::MIME"text/plain", bf::BroughtField) =
    display_blueprint_field_long(io, bf)

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

function display_blueprint_field_long(io::IO, bf::BroughtField, level)
    grey = crayon"black"
    reset = crayon"reset"
    (; value) = bf
    if isnothing(value)
        print(io, "$grey<no blueprint brought>$reset")
    elseif value isa CompType
        print(io, "$grey<implied blueprint for $reset$value$grey>$reset")
    elseif value isa Blueprint
        print(io, "$grey<embedded $reset")
        display_long(io, value, level)
        print(io, "$grey>$reset")
    else
        throw("unreachable: invalid brought blueprint field value: \
               $(repr(value)) ::$(typeof(value))")
    end
end
