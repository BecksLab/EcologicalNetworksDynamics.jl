# Convenience macro for defining methods and properties.
#
# Invoker defines the behaviour in a function code containing at least one 'receiver':
# an argument typed with the system wrapped value.
#
#   f(v::Value, ...) = <invoker code>
#
# If no receiver is found, the first argument is assumed to be it if it's `::Any`.
#
# Then, the macro invokation goes like:
#
#   @method f depends(components...) read_as(names...) # or write_as(names...)
#
# Or alternately:
#
#   @method begin
#       function_name # or function_name{ValueType} if inference fails.
#       depends(components...)
#       read_as(property_names...) # or write_as(property_names...)
#   end
#
# This will generate additional methods to `f` so it accepts `System{Value}` instead of
# `Value` as the receiver. These method check that components dependencies are met
# before forwarding to the original method.
#
# If an original method has the exact:
#  - `f(receiver)` signature, then it can be marked as a `read` property.
#  - `f(receiver, rhs)` signature, then it can be marked as a `write` property.
#
# Sometimes, the method needs to take decision
# depending on other system components that are not strict dependencies,
# so the whole system needs to be queried and not just the wrapped value.
# In this case, the invoker may add a 'hook' `::System` parameter to their signature:
#
#   f(v, a, b, _system::System) = ...
#
# The new method generated will then elide this extra 'hook' argument,
# yet forward the whole system to it:
#
#   f(v::System{ValueType}, a, b) = f(v._value, a, b, v) # (generated)
#
macro method(input...)
    method_macro(__module__, __source__, input...)
end
export @method

# Extract function to ease debugging with Revise.
function method_macro(__module__, __source__, input...)

    # Push resulting generated code to this variable.
    res = quote end
    push_res!(xp) = xp.head == :block ? append!(res.args, xp.args) : push!(res.args, xp)

    # Raise *during expansion* if parsing fails.
    perr(mess) = throw(ItemMacroParseError(:method, __source__, mess))

    # Raise *during execution* if the macro was invoked with inconsistent input.
    # (assuming `fn` generated variable has been set)
    src = Meta.quot(__source__)
    push_res!(quote
        fn = nothing # Refined later.
        xerr = (mess) -> throw(ItemMacroExecError(:method, fn, $src, mess))
    end)

    # Convenience wrap.
    tovalue(xp, ctx, type) = to_value(__module__, xp, ctx, :xerr, type)
    todep(xp, ctx) = to_dependency(__module__, xp, ctx, :xerr)

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
             | @method begin\n\
             |      function_name\n\
             |      depends(...)\n\
             |      read_as(...)\n\
             | end\n",
        )
    end

    # The first section needs to specify the function containing adequate behaviour code.
    # Since an additional method to this function needs to be generated,
    # then the input expression must be a plain symbol or Path.To.symbol..
    # unless there is another programmatic way to add a method to a function in Julia?
    xp = input[1]
    fn_xp, ValueType_xp = nothing, nothing # (hepl JuliaLS)
    @capture(xp, fn_xp_{ValueTypeXp_} | fn_xp_)
    fn_xp isa Symbol ||
        fn_xp isa Expr && fn_xp.head == :. ||
        perr("Not a method identifier or path: $(repr(fn_xp)).")
    ValueType_xp =
        isnothing(ValueType_xp) ? :(nothing) :
        tovalue(ValueType_xp, "System value type", Type)
    push_res!(quote

        ValueType = $ValueType_xp # Explicit or uninferred.
        fn = $(tovalue(fn_xp, "System method", Function))

    end)

    # Next come other optional specifications in any order.
    deps_xp = nothing # Evaluates to [components...]
    proptype = nothing
    propsymbols = []
    read_kw, write_kw = (:read_as, :write_as)
    kw = nothing

    for i in input[2:end]

        # Dependencies section: specify the components required to use the method.
        list = nothing # (help JuliaLS)
        @capture(i, depends(list__))
        if !isnothing(list)
            isnothing(deps_xp) || perr("The `depends` section is specified twice.")
            deps_xp = :([])
            first = true
            for dep in list
                if first
                    # Infer the value type from the first dep if possible.
                    xp = quote
                        C = $(todep(dep, "First dependency"))
                        if isnothing(ValueType)
                            ValueType = system_value_type(C)
                        else
                            if !(C <: Component{ValueType})
                                actual_V = system_value_type(C)
                                xerr("Depends section: system value type
                                      is supposed to be '$ValueType' \
                                      based on the first macro argument, \
                                      but '$C' subtypes '$(Component{actual_V})' \
                                      and not '$(Component{ValueType})'.")
                            end
                        end
                        C
                    end
                    first = false
                else
                    xp = todep(dep, "Depends section")
                end
                push!(deps_xp.args, xp)
            end
            continue
        end

        # Property section: specify whether the code can be accessed as a property.
        kw, propnames = nothing, nothing # (help JuliaLS)
        @capture(i, kw_(propnames__))
        if !isnothing(kw)
            if Base.isidentifier(kw)
                if !(kw in (read_kw, write_kw))
                    perr("Invalid section keyword: $(repr(kw)). \
                          Expected `$read_kw` or `$write_kw` or `depends`.")
                end
                if !isnothing(proptype)
                    proptype == kw && perr("The `$kw` section is specified twice.")
                    perr("Cannot specify both `$proptype` section and `$kw`.")
                end
                for pname in propnames
                    pname isa Symbol ||
                        perr("Property name is not a simple identifier: $(repr(pname)).")
                end
                propsymbols = Meta.quot.(propnames)
                proptype = kw
                continue
            end
        end

        perr("Unexpected @method section. \
              Expected `depends(..)`, `$read_kw(..)` or `$write_kw(..)`. \
              Got: $(repr(i)).")

    end

    if isnothing(deps_xp)
        deps_xp = :([])
    end

    if isempty(deps_xp.args)
        push_res!(
            quote
                isnothing(ValueType) && xerr("The system value type cannot be inferred \
                                              when no dependencies are given.
                                              Consider making it explicit \
                                              with the first macro argument: \
                                              `$fn{MyValueType}`.")
            end,
        )
    end

    push_res!(quote
        # Collect the dependencies now as it enables inferring the system value type.
        raw_deps = $deps_xp
    end)

    # Scroll existing methods to find the ones to override.
    push_res!(
        quote
            to_override = []
            for mth in methods(fn)

                # Retrieve fixed-parameters types for the method.
                parms = collect(mth.sig.parameters[2:end])
                isempty(parms) && continue
                # Retrieve their names.
                # https://discourse.julialang.org/t/get-the-argument-names-of-an-function/32902/4?u=iago-lito
                names =
                    ccall(:jl_uncompress_argnames, Vector{Symbol}, (Any,), mth.slot_syms)[2:end]

                # Among them, find the one to use as the system 'receiver',
                # and the possible one to use as the 'hook'.
                values = Set()
                system_values = Set()
                systems_only = Set()
                for (p, n) in zip(parms, names)
                    p isa Core.TypeofVararg && continue
                    p <: ValueType && push!(values, n)
                    p <: System{ValueType} && push!(system_values, n)
                    p === System && push!(systems_only, n)
                end
                severr =
                    (what, set, type) ->
                        xerr("Receiving several (possibly different) $what \
                              is not yet supported by the framework. \
                              Here both :$(pop!(set)) and :$(pop!(set)) \
                              are of type $type.")
                length(values) > 1 && xerr("system/values parameters", values, ValueType)
                receiver = if isempty(values)
                    parms[1] === Any || continue
                    names[1]
                else
                    pop!(values)
                end
                sv = system_values
                length(sv) > 1 && severr("system hooks", sv, System{ValueType})
                hook = if isempty(system_values)
                    so = systems_only
                    length(so) > 1 && severr("system hooks", so, System)
                    isempty(so) ? nothing : pop!(so)
                else
                    pop!(system_values)
                end

                # Record for overriding.
                push!(to_override, (mth, parms, names, receiver, hook))
            end
            isempty(to_override) &&
                xerr("No suitable method has been found to mark $fn as a system method. \
                      Valid methods must have at least \
                      one 'receiver' argument of type ::$ValueType \
                      or a first ::Any argument to be implicitly considered as such.")
        end,
    )

    # Check that consistent 'depends' component types have been specified.
    push_res!(
        quote
            deps = OrderedSet{CompType{ValueType}}()

            # Now that we have a guarantee that 'ValueType' has been completely inferred,
            # use it to guard against redundant method specifications.
            (specified_as_method(ValueType, typeof(fn)) && !REVISING) &&
                xerr("Function '$fn' already marked as a method \
                      for '$(System{ValueType})'.")

            for Dep in raw_deps
                for Already in deps
                    vertical_guard(
                        Dep,
                        Already,
                        () -> xerr("Dependency '$Dep' is specified twice."),
                        (Sub, Sup) -> xerr("Dependency $Sub is also specified as $Sup."),
                    )
                end
                push!(deps, Dep)
            end
        end,
    )

    if kw == read_kw
        push_res!(quote
            try
                which(fn, Tuple{ValueType})
            catch
                xerr("The function '$fn' cannot be called \
                      with exactly 1 argument of type '$ValueType' \
                      as required to be set as a 'read' property.")
            end
        end)
    end

    if kw == write_kw
        push_res!(
            quote
                # The assessment is trickier here
                # since there may be a constraint on the second argument,
                # although there is no restriction which constraint,
                # so which(fn, Tuple{ValueType,Any}) would incorrectly fail.
                # The best I've found then is to scroll all methods
                # until we find a match for the desired signature.
                # Maybe there is a better way to do this in julia?
                match = any(Iterators.map(methods(fn)) do m
                    parms = m.sig.parameters
                    length(parms) == 3 && ValueType <: parms[2]
                end)
                if !match
                    xerr("The function '$fn' cannot be called with exactly 2 arguments, \
                          the first one being of type '$ValueType', \
                          as required to be set as a 'write' property.")
                end
            end,
        )
    end

    # Check properties availability.
    propsymbols = map(s -> first(s.args), propsymbols)
    push_res!(
        if kw == read_kw
            quote
                for psymbol in $[propsymbols...]
                    has_read_property(ValueType, Val(psymbol)) &&
                        xerr("The property $psymbol is already defined \
                              for $($System){$ValueType}.")
                end
            end
        else
            quote
                for psymbol in $[propsymbols...]
                    has_read_property(ValueType, Val(psymbol)) ||
                        xerr("The property $psymbol cannot be marked 'write' \
                              without having first been marked 'read' \
                              for $($System){$ValueType}.")
                    has_write_property(ValueType, Val(psymbol)) &&
                        xerr("The property $psymbol is already marked 'write' \
                              for $($System){$ValueType}.")
                end
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

    # Generate dependencies method.
    push_res!(quote
        Framework.depends(::Type{ValueType}, ::Type{typeof(fn)}) = deps
    end)

    # Generate the method checking that required components
    # are loaded on the system instance.
    push_res!(
        quote
            function Framework.missing_dependency_for(
                ::Type{ValueType},
                M::Type{typeof(fn)},
                s::System,
            )
                for dep in depends(ValueType, M)
                    has_component(s, dep) || return dep
                end
                nothing
            end
        end,
    )

    # Override the detected methods with checked code receiving system values.
    efn = LOCAL_MACROCALLS ? esc(fn_xp) : Meta.quot(:($__module__.$fn_xp))
    fn_path = Meta.quot(Meta.quot(fn_xp))
    push_res!(
        quote
            for (mth, parms, pnames, receiver, hook) in to_override
                # Start from dummy (; kwargs...) signature/forward call..
                # Hygienic temporary variables, generated for the target module.
                local dep, a = Core.eval($__module__, :(gensym.([:dep, :a])))
                xp = quote
                    function $($efn)(; kwargs...)
                        #  function $mod.$fnname(; kwargs...)
                        $dep = missing_dependency_for($ValueType, $($efn), $receiver)
                        if !isnothing($dep)
                            $a = isabstracttype($dep) ? " a" : ""
                            throw(
                                MethodError(
                                    $ValueType,
                                    $($fn_path),
                                    "Requires$($a) component $($dep).",
                                ),
                            )
                        end
                        $($efn)(; kwargs...)
                    end
                end
                # .. then fill them up from the collected names/parameters.
                parms_xp = xp.args[2].args[1].args #  (fetch the `(; kwargs)` in signature)
                args_xp = xp.args[2].args[2].args[end].args # (fetch the same in the call)
                for (name, type) in zip(pnames, parms)
                    parm, arg = if type isa Core.TypeofVararg
                        # Forward variadics as-is.
                        (:($name::$(type.T)...), :($name...))
                    else
                        if name == receiver
                            # Dispatch signature on the system to transmit the inner value
                            # to the call.
                            (:($name::System{$ValueType}), :($name._value))
                        elseif name == hook
                            # Don't receive at all, but transmit from the receiver.
                            (nothing, receiver)
                        else
                            # All other arguments are forwarded as-is.
                            (:($name::$type), name)
                        end
                    end
                    isnothing(parm) || push!(parms_xp, parm)
                    push!(args_xp, arg)
                end
                eval(xp)
            end
            # TODO: if unexistent, then
            # defining a fallback `fn(value, args...; _system=s, kwargs...)` method here
            # would enable that implementors of `fn` take decisions
            # depending on the whole system value, and components currently available.
            # In particular, it would avoid the need
            # to define both `_simulate` and `simulate` in the exposed lib.
        end,
    )

    # Property specification.
    # (for getproperty(s::System, ..))
    if !isnothing(proptype)
        set = (proptype == read_kw) ? :set_read_property! : :set_write_property!
        push_res!(quote
            for psymbol in $[propsymbols...]
                $set(ValueType, psymbol, fn)
            end
        end)
    end

    # Record as specified to avoid it being recorded again.
    push_res!(quote
        Framework.specified_as_method(::Type{ValueType}, ::typeof(fn)) = true
    end)

    # Avoid confusing/leaky return type from macro invocation.
    push_res!(quote
        nothing
    end)

    res
end

# Check whether the function has already been specified as a @method.
specified_as_method(::Type, ::Type{<:Function}) = false
