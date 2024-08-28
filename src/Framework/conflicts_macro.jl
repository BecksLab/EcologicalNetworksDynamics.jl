# Convenience macro for specifying a set of conflicting components,
# and optionally some of the reasons they conflict.
#
# Full use:
#
#     @conflicts(
#         A => (B => "reason", C => "reason"),
#         B => (A => "reason", C => "reason'),
#         C => (A => "reason", B => "reason"),
#     )
#
# Only the keys are required, and any reason can be omitted:
#
#     @conflicts(
#         A,
#         B => (C => "reason"),
#         C,
#     )
#
# Minimal use: @conflicts(A, B, C)
macro conflicts(input...)
    conflicts_macro(__module__, __source__, input...)
end
export @conflicts

# Extract function to ease debugging with Revise.
function conflicts_macro(__module__, __source__, input...)

    # Push resulting generated code to this variable.
    res = quote end
    push_res!(xp) = xp.head == :block ? append!(res.args, xp.args) : push!(res.args, xp)

    # Raise *during expansion* if parsing fails.
    perr(mess) = throw(ConflictMacroParseError(__source__, mess))

    # Raise *during execution* if the macro was invoked with inconsistent input.
    src = Meta.quot(__source__)
    push_res!(quote
        xerr = (mess) -> throw(ConflictMacroExecError($src, mess))
    end)

    # Convenience wrap.
    tovalue(xp, ctx, type) = to_value(__module__, xp, ctx, :xerr, type)
    tocomp_novaluetype(xp, ctx) = to_component(__module__, xp, ctx, :xerr)
    tocomp(xp, ctx) = to_component(__module__, xp, :ValueType, ctx, :xerr)

    #---------------------------------------------------------------------------------------
    # Parse macro input,
    # while also generating code checking invoker input within invocation context.

    length(input) == 0 && perr("No macro arguments provided. \
                                Example usage:\n\
                                |  @conflicts(A, B, ..)\n\
                                ")


    # Infer the underlying system value type from the first argument.
    first_entry = nothing
    entries = :([])
    for entry in input

        comp, conf, invalid, reasons, mess = repeat([nothing], 5) # (help JuliaLS)
        #! format: off
        @capture(entry,
            (comp_ => (reasons__,)) |
            (comp_ => [reasons__]) |
            (comp_ => (conf_ => mess_)) | # Special-case single reason without comma.
            (comp_ => invalid_) |
            comp_
        )
        #! format: on
        isnothing(conf) || (reasons = [:($conf => $mess)])
        isnothing(invalid) || perr("Not a list of conflict reasons: $(repr(invalid)).")
        isnothing(reasons) && (reasons = [])

        if isnothing(first_entry)
            ctx = "First conflicting entry"
            push_res!(
                quote
                    First = $(tocomp_novaluetype(comp, ctx))
                    ValueType = system_value_type(First)
                end,
            )
            first_entry = comp
            comp = :First
        else
            comp = tocomp(comp, "Conflicting entry")
        end

        reasons_xp = :([])
        for reason in reasons
            @capture(reason, (conf_ => mess_))
            isnothing(conf) &&
                perr("Not a `Component => \"reason\"` pair: $(repr(reason)).")
            conf = tocomp(conf, "Reason reference")
            mess = tovalue(mess, "Reason message", String)
            push!(reasons_xp.args, :($conf, $mess))
        end

        push!(entries.args, :($comp, $reasons_xp))

    end

    length(entries.args) == 1 &&
        perr("At least two components are required to declare a conflict \
              not only $(repr(first_entry)).")

    # Declare all conflicts, checking that provided reasons do refer to listed conflicts.
    push_res!(
        quote
            entries = $entries
            comps = CompType{ValueType}[first(e) for e in entries]
            keys = OrderedSet{CompType{ValueType}}(comps)
            for (a, reasons) in entries
                for (b, message) in reasons
                    b in keys ||
                        xerr("Conflict reason does not refer to a component listed \
                              in the same @conflicts invocation: $b => $(repr(message)).")
                    declare_conflict(a, b, message, xerr)
                end
            end
            declare_conflicts_clique(xerr, comps)
        end,
    )

    # Avoid confusing/leaky return type from macro invocation.
    push_res!(quote
        nothing
    end)

    res

end
