function generate_dbdt_compact(parms::ModelParameters)

    # Prepare collection of pre-calculated data.
    data = Dict()

    code = :(function (dB, B, data, t)

        # Lines are generated here.

    end)

    # Gather all generated code and data.
    chunks_generators = [
        parms.functional_response,
        # Calculate consumption terms first
        # because they constitute a full pass over all dB[i] values
        # and it's an opportunity to initialize them.
        consumption,
        # Then the other terms, which may be done in partial passes.
        growth,
        metabolism_loss,
    ]
    chunks = []
    data = Dict()
    for gen in chunks_generators
        # Correctly dispatch with dummy :_ symbol arguments.
        # Alternative: move FunctionalResponse functor definitions
        # in a dedicated file *after* 'ModelParameters' has been declared
        # so it may appear in their signature.
        c, d = gen(parms, :_)
        append!(chunks, c)
        for (k, v) in d
            if haskey(data, k) && v != data[k]
                throw(
                    "Error in package source: \n" *
                    "$(gen) code generator produced data '$(k)': $v " *
                    "($(typeof(v)))\n" *
                    "inconsistently with previously generated data '$(k)': $(data[k]) " *
                    "($(typeof(data[k])))\n",
                )
            end
            data[k] = v
        end
    end

    # Construct/compile one large named tuple from the data.
    # Also, one large destructuring assignment line
    # to have all members available as plain variables
    # for the rest of the generated code.
    structuring = Expr(:tuple)
    destructuring = :(() = data)
    for (k, v) in data
        push!(structuring.args, Expr(:(=), k, v))
        push!(destructuring.args[1].args, k)
    end
    data = eval(structuring)

    # Insert all these lines and chunks into the generated function.
    push_line!(line) = push!(code.args[2].args, line)
    push_line!(destructuring)
    for l in chunks
        push_line!(l)
    end

    return code, data
end
