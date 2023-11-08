
# This function duplicates `extract_last_timesteps` from the internals,
# which should disappear in the future.
function tail(
    solution::Solution,
    last = 1;
    species = nothing,
    warn_late_extinctions = true,
    kwargs...,
)
    # Extract last timesteps.
    n = length(solution.t)
    last = tail_length(last, n; kwargs...)
    res = solution[:, end-last+1:end]

    # Extract species indices:
    m = ref_model(solution)
    index = m.species_index
    idxs = species_indices(species, index)
    res = res[idxs, :]

    # Extinction events are typically expected to occur before the extracted timesteps.
    if warn_late_extinctions && size(res, 2) > 0
        ext = extinct_species_indices(solution)
        tail_start = solution.t[end-last+1]
        for i_species in idxs
            if haskey(ext, i_species)
                time = ext[i_species]
                if time >= tail_start
                    name = first(n for (n, i) in index if i == i_species)
                    @warn("Species $i_species ($(repr(name))) went extinct at time $time, \
                           during the extracted simulation tail.")
                end
            end
        end
    end

    deepcopy(res) # Don't alias raw solution data.
end
export tail

# Parse user input to decide how many timesteps to output in 'tail'.
function tail_length(input, n; warn_empty_tail = true)

    # Parse 'last' into an actual number of timesteps.

    if input isa AbstractString
        endswith(input, "%") ||
            argerr("The `last` argument, when given as a string, should end with '%'.")
        perc = parse(Float64, input[1:(end-1)])
        is_valid_perc = 0.0 <= perc <= 100.0
        is_valid_perc || argerr("Cannot extract $input of the solution's timesteps: \
                                 0% <= `last` <= 100% must hold.")
        last = round(Int, n * perc / 100)
        (warn_empty_tail && last == 0) && @warn("$perc% of $n timestep$(s(n)) \
                                                 correspond to $last output lines: \
                                                 the solution tail is an empty table.")
    elseif input isa Integer
        input >= 0 || argerr("Cannot extract '$input' timesteps. \
                             `last` should be a positive integer.")
        (warn_empty_tail && input == 0) &&
            @warn("Solution tail of size 0 is an empty table.")
        last = input
    elseif input isa AbstractFloat
        argerr("Invalid `last` specification: '$input::$(typeof(input))'. \
                Did you mean \"$input%\"::String?")
    else
        argerr("Invalid `last` specification. \
                Expected positive integer or percentage string. \
                Got instead: '$input::$(typeof(input))'.")
    end

    last > n && argerr("Cannot extract $last timestep$(s(last)) from a trajectory solution \
                        with only $n timestep$(s(n)). \
                        Consider decreasing the `last` argument value \
                        and/or specifying it as a percentage instead (e.g. `\"10%\"`).")

    last

end
s(n) = n > 0 ? "s" : ""

# Parse user input to calculate species indices to extract from the solution.
function species_indices(input, index::OrderedDict{Symbol,Int64})

    isnothing(input) && return collect(values(index))

    # Extract single values into singleton collection.
    for Singleton in [AbstractString, Char, Symbol, Integer]
        if input isa Singleton
            input = [input]
            break
        end
    end

    # Collect indices.
    applicable(iterate, input) || argerr("Not an iterable of species identifiers: \
                                          $(repr(input))::$(typeof(input)).")
    res = []

    if first(input) isa Integer
        # Assume raw indices are given.
        n = length(index)
        for i in input
            i isa Integer || argerr("First value was a species index ($(first(input))), \
                                     but this subsequent value \
                                     is not a species index: $(repr(i))::$(typeof(i))")
            0 < i <= n || argerr(
                "Invalid species index when there $(n > 1 ? "are" : "is") $n species: $i.",
            )
            push!(res, i)
        end
    else
        # Assume names are given.
        for raw in input
            name = try
                GraphDataInputs.graphdataconvert(Symbol, raw)
            catch
                argerr("Not a species raw or index: $(repr(raw))::$(typeof(raw)).")
            end
            haskey(index, name) || argerr("Invalid species name: $(repr(raw)). \
                                           Expected \
                                           $(join(repr.(keys(index)), ", ", " or ")).")
            push!(res, index[name])
        end
    end

    res
end
