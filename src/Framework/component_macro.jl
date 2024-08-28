# Convenience macro for defining a new component.
#
# Invoker defines possible abstract component supertype,
# and/or some blueprints types providing only the created component,
# then invokes:
#
#   @component Name{ValueType} requires(components...) blueprints(name::Type, ...)
#
# Or:
#
#   @component Name <: SuperComponentType requires(components...) blueprints(name::Type, ...)
#
# This alternate block-form is supported:
#
#   @component begin
#       Name{ValueType}
#  (or) Name <: SuperComponentType
#       requires(components...)
#       blueprints(name::Type, ...)
#   end
#
# Consistency checks are run by the macro then by the generated code.
# When all check pass, the following (approximate) component code
# should result from expansion:
#
# ------------------------------------------------------------------
#   # Component type.
#   struct _Name <: SuperComponentType (or Component{ValueType})
#     Blueprint1::Type{Blueprint{ValueType}}
#     Blueprint2::Type{Blueprint{ValueType}}
#     ...
#   end
#
#   # Component singleton value.
#   const Name = _Name(
#       BlueprintType1,
#       BlueprintType2,
#       ...
#   )
#   singleton_instance(::Type{_Name}) = Name
#
#   # Base blueprints.
#   componentsof(::Blueprint1) = (_Name,)
#   componentsof(::Blueprint2) = (_Name,)
#   ...
#
#   requires(::Type{_Name}) = ...
# ------------------------------------------------------------------
#
macro component(input...)
    # Extract function to ease debugging with Revise.
    component_macro(__module__, __source__, input...)
end
export @component

function component_macro(__module__, __source__, input...)

    # Push resulting generated code to this variable.
    res = quote end
    push_res!(xp) = xp.head == :block ? append!(res.args, xp.args) : push!(res.args, xp)

    # Raise *during expansion* if parsing fails.
    perr(mess) = throw(ItemMacroParseError(:component, __source__, mess))

    # Raise *during execution* if the macro was invoked with inconsistent input.
    # (assuming the `NewComponent` generated variable has been set)
    src = Meta.quot(__source__)
    push_res!(
        quote
            NewComponent = nothing # Refined later.
            xerr =
                (mess) -> throw(ItemMacroExecError(:component, NewComponent, $src, mess))
        end,
    )

    # Convenience local wrap.
    tovalue(xp, ctx, type) = to_value(__module__, xp, ctx, :xerr, type)
    tobptype(xp, ctx) = to_blueprint_type(__module__, xp, :ValueType, ctx, :xerr)
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
             | @component begin\n\
             |      Name <: SuperComponent\n\
             |      requires(...)\n\
             |      blueprints(...)\n\
             | end\n",
        )
    end

    # Extract component name, value type and supercomponent from the first section.
    component_xp = input[1]
    name, value_type, super = nothing, nothing, nothing # (to help JuliaLS)
    @capture(component_xp, name_{value_type_} | (name_ <: super_))
    isnothing(name) &&
        perr("Expected component `Name{ValueType}` or `Name <: SuperComponent`, \
              got instead: $(repr(component_xp)).")
    if !isnothing(super)
        # Infer value type from the abstract supercomponent.
        # Same, for abstract component types.
        super isa Symbol || perr("Expected supercomponent symbol, got: $(repr(super)).")
        push_res!(
            quote
                SuperComponent =
                    $(tovalue(super, "Evaluating given supercomponent", DataType))
                if !(SuperComponent <: Component)
                    xerr(
                        "Supercomponent: '$SuperComponent' does not subtype '$Component'.",
                    )
                end
                ValueType = system_value_type(SuperComponent)
            end,
        )
    elseif !isnothing(value_type)
        push_res!(
            quote
                ValueType =
                    $(tovalue(value_type, "Evaluating given system value type", DataType))
                SuperComponent = Component{ValueType}
            end,
        )
    end
    component_name = name
    component_sym = Meta.quot(name)
    component_type = Symbol(:_, name)
    push_res!(
        quote
            isdefined($__module__, $component_sym) &&
                xerr("Cannot define component '$($component_sym)': name already defined.")
            NewComponent = $component_sym
        end,
    )

    # Next come other optional sections in any order.
    requires_xp = nothing # Evaluates to [(component => reason), ...]
    blueprints_xp = nothing # Evaluates to [(identifier, paths), ...]

    for i in input[2:end]

        # Require section: specify necessary components.
        reqs = nothing # (help JuliaLS)
        @capture(i, requires(reqs__))
        if !isnothing(reqs)
            isnothing(requires_xp) || perr("The `requires` section is specified twice.")
            requires_xp = :([])
            for req in reqs
                # Set requirement reason to 'nothing' if unspecified.
                comp, reason = nothing, nothing # (help JuliaLS)
                @capture(req, comp_ => reason_)
                if isnothing(reason)
                    comp = req
                else
                    reason = tovalue(reason, "Requirement reason", String)
                end
                comp = todep(comp, "Required component")
                req = :($comp => $reason)
                push!(requires_xp.args, req)
            end
            continue
        end

        # Blueprints section: specify blueprints providing the new component.
        bps = nothing # (help JuliaLS)
        @capture(i, blueprints(bps__))
        if !isnothing(bps)
            isnothing(blueprints_xp) || perr("The `blueprints` section is specified twice.")
            blueprints_xp = :([])
            for bp in bps
                bpname, B = nothing, nothing # (help JuliaLS)
                @capture(bp, bpname_::B_)
                isnothing(bpname) &&
                    perr("Expected `name::Type` to specify blueprint, found $(repr(bp)).")
                is_identifier_path(B) ||
                    perr("Not a blueprint identifier path: $(repr(B)).")
                xp = tobptype(B, "Blueprint")
                push!(blueprints_xp.args, :($(Meta.quot(bpname)), $xp))
            end
            continue
        end

        perr("Invalid @component section. \
              Expected `requires(..)` or `blueprints(..)`, \
              got instead: $(repr(i)).")

    end
    isnothing(requires_xp) && (requires_xp = :([]))
    isnothing(blueprints_xp) && (blueprints_xp = :([]))

    # Check that consistent required component types have been specified.
    push_res!(
        quote

            # Required components.
            reqs = CompsReasons{ValueType}()
            for (Req, reason) in $requires_xp
                # Triangular-check against redundancies,
                # checking through abstract types.
                for (Already, _) in reqs
                    vertical_guard(
                        Req,
                        Already,
                        () -> xerr("Requirement $Req is specified twice."),
                        (Sub, Sup) -> xerr("Requirement $Sub is also specified as $Sup."),
                    )
                end
                reqs[Req] = reason
            end
        end,
    )

    # Guard against redundancies among base blueprints.
    push_res!(quote
        base_blueprints = []
        for (name, B) in $blueprints_xp
            # Triangular-check.
            for (other, Other) in base_blueprints
                other == name && xerr("Base blueprint $(repr(other)) \
                                       both refer to $Other and to $B.")
                Other == B && xerr("Base blueprint $B bound to \
                                    both names $(repr(other)) and $(repr(name))")
            end
            push!(base_blueprints, (name, B))
        end
    end)

    #---------------------------------------------------------------------------------------
    # At this point, all necessary information should have been parsed and checked,
    # both at expansion time (within this very macro body code)
    # and generated code execution time
    # (within the code currently being generated although not executed yet).
    # The only remaining code to generate work is just the code required
    # for the system to work correctly.

    # Construct the component type, with base blueprints types as fields.
    ena = esc(component_name)
    ety = esc(component_type)
    enas = Meta.quot(component_name)
    etys = Meta.quot(component_type)
    push_res!(quote
        str = quote
            struct $($etys) <: $SuperComponent end
        end
        for (name, B) in base_blueprints
            push!(str.args[2].args[3].args, quote
                $name::Type{$B}
            end)
        end
        $__module__.eval(str)
    end)

    # Construct the singleton instance.
    push_res!(
        quote
            cstr = :($($etys)())
            for (_, B) in base_blueprints
                push!(cstr.args, B)
            end
            cstr = quote
                const $($enas) = $cstr
            end
            $__module__.eval(cstr)
            # Connect instance to type.
            Framework.singleton_instance(::Type{$ety}) = $ena
            # Ensure singleton unicity.
            (C::Type{$ety})(args...; kwargs...) =
                throw("Cannot construct other instances of $C.")
        end,
    )

    # Connect to blueprint types.
    push_res!(quote
        for (_, B) in base_blueprints
            $__module__.eval(quote
                $Framework.componentsof(::$B) = $($ety,)
            end)
        end
    end)

    # Setup the components required.
    push_res!(
        quote
            Framework.requires(::Type{$ety}) =
                CompsReasons{ValueType}(k => v for (k, v) in reqs) # Copy to avoid leaks.
        end,
    )


    # Helpful display resuming base blueprint types for this component.
    push_res!(
        quote
            function Base.show(io::IO, ::MIME"text/plain", C::$ety)
                print(io, "$C $(crayon"black")(component for $ValueType, expandable from:")
                for name in fieldnames(typeof(C))
                    bp = getfield(C, name)
                    print(io, "\n  $name: $bp,")
                end
                print(io, "\n)$(crayon"reset")")
            end
        end,
    )

    # Avoid confusing/leaky return type from macro invocation.
    push_res!(quote
        nothing
    end)

    res
end

#-------------------------------------------------------------------------------------------
# The 'conflicts_' mapping entries are either abstract or concrete component,
# which makes checking information for one particular component not exactly straighforward.

# (for some reason this is absent from Base)
function supertypes(T::Type)
    S = supertype(T)
    S === T ? (T,) : (T, supertypes(S)...)
end

# Iterate over all conflicting entries with the given component or a supercomponent of it.
super_conflict_keys(C::CompType) =
    Iterators.filter(supertypes(C)) do sup
        conflicts_(sup)
    end

# Iterate over all conflicts for one particular component.
# yields (conflict_key, conflicting_component, reason)
# The yielded conflict key may be a supercomponent of the focal one.
function all_conflicts(C::CompType)
    Iterators.flatten(Iterators.map(super_conflict_keys(C)) do key
        Iterators.map(conflicts_(key)) do (conflicting, reason)
            (key, conflicting, reason)
        end
    end)
end

# Guard against declaring conflicts between sub/super components.
function vertical_conflict(err)
    (sub, sup) -> begin
        it = sub === sup ? "itself" : "its own super-component '$sup'"
        err("Component '$sub' cannot conflict with $it.")
    end
end

# Declare one particular conflict with a reason.
# Guard against redundant reasons specifications.
function declare_conflict(A::CompType, B::CompType, reason::Reason, err)
    vertical_guard(A, B, vertical_conflict(err))
    for (k, c, reason) in all_conflicts(A)
        isnothing(reason) && continue
        if B <: c
            as_K = k === A ? "" : " (as '$k')"
            as_C = B === c ? "" : " (as '$c')"
            err("Component '$A'$as_K already declared to conflict with '$B'$as_C \
                 for the following reason:\n  $(reason)")
        end
    end
    # Append new method or override by updating value.
    current = conflicts_(A) # Creates a new empty value if falling back on default impl.
    if isempty(current)
        # Dynamically add method to lend reference to the value lended by `conflicts_`.
        eval(quote
            conflicts_(::Type{$A}) = $current
        end)
    end
    current[B] = reason
end

# Fill up a clique, not overriding any existing reason.
function declare_conflicts_clique(err, components::Vector{<:CompType{V}}) where {V}

    function process_pair(A::CompType{V}, B::CompType{V})
        vertical_guard(A, B, vertical_conflict(err))
        # Same logic as above.
        current = conflicts_(A)
        if isempty(current)
            eval(quote
                conflicts_(::Type{$A}) = $current
            end)
        end
        haskey(current, B) || (current[B] = nothing)
    end

    # Triangular-iterate to guard against redundant items.
    for (i, a) in enumerate(components)
        for b in components[1:(i-1)]
            process_pair(a, b)
            process_pair(b, a)
        end
    end

end

