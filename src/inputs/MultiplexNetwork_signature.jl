# This technical, helper file contains the machinery
# to make the sophisticated signature of MultiplexNetwork() function work.

# For use within this file.
pstandards() = standards(MultiplexParametersDict)
istandards() = standards(InteractionDict)
pstandard(p) = standardize(p, MultiplexParametersDict)
istandard(i) = standardize(i, InteractionDict)
p_references() = references(MultiplexParametersDict)
i_references() = references(InteractionDict)

############################################################################################
# Protect against aliasing ambiguity. ######################################################
############################################################################################

# Check for non-ambiguity between parameters and interactions references.
for p in p_references(), i in i_references()
    # Protect against confusion between interaction names and parameters names.
    if i == p
        I = istandard(i)
        P = pstandard(p)
        throw("Ambiguous parametrization aliasing for MultiplexNetwork: " *
              "'$p' either means '$I' or '$P'.")
    end
end

# Separate argument name into all valid combinations of one or two references.
function arg_parses(arg)
    arg = Symbol(arg)
    irefs = i_references()
    prefs = p_references()
    # Split on all '_' separators, then collect alls that yield a perfect (p, i) match.
    parses = []
    # Collect trivial, non-combinations first.
    if arg in prefs
        push!(parses, (arg, nothing))
    end
    if arg in irefs
        push!(parses, (nothing, arg))
    end
    arg = string(arg)
    bits = split(arg, '_')
    for k in 1:(length(bits)-1)
        p = Symbol(join(bits[1:k], '_'))
        i = Symbol(join(bits[k+1:end], '_'))
        if p in prefs && i in irefs
            push!(parses, (p, i))
        end
    end
    parses
end
# Turn the result of the above function into something useful for an error message.
function parse_message(p::Union{Nothing,Symbol}, i::Union{Nothing,Symbol})
    if isnothing(p)
        I = istandard(i)
        "'$I interaction' ($i)"
    elseif isnothing(i)
        P = pstandard(p)
        "'parameter $P' ($p)"
    else
        P = pstandard(p)
        I = istandard(i)
        "'parameter $P for $I interaction' ($p::$i)"
    end
end
# Protect against ambiguous arguments splitting.
function ambiguity_guard(arg)
    parses = arg_parses(arg)
    if length(parses) > 1
        # There is lexical ambiguity,
        # but no semantic ambiguity if all meanings are the same.
        # Filter out identical meanings
        ((p1, i1),) = parses
        different = [(p1, i1)]
        for (p, i) in parses
            if pstandard(p) != pstandard(p1) || istandard(i) != istandard(i1)
                push!(different, (p, i))
            end
        end
        if length(different) > 1
            # That's a true semantic ambiguity.
            (p1, i1), (p2, i2) = different
            throw("Ambiguous parametrization aliasing for MultiplexNetwork: " *
                  "argument '$arg' would either mean $(parse_message(p1, i1)), " *
                  "or $(parse_message(p2, i2)).")
        end
    end
end
for arg in p_references()
    ambiguity_guard(arg)
end
for arg in i_references()
    ambiguity_guard(arg)
end
for iref in i_references(), pref in p_references()
    ambiguity_guard(Symbol("$(pref)_$(iref)"))
end

############################################################################################
# Parse function arguments into relevant parameters. #######################################
############################################################################################

# Improve error messages by keeping track of the exact way arguments were input.
abstract type MultiplexNetworkArg end
for T in [:BasalArg, :ParmIntNestedArg, :IntParmNestedArg]
    eval(:(struct $T <: MultiplexNetworkArg
        p::Symbol # Parameter argument part (:A, :sym, :connectance..)
        i::Symbol # Interaction argument part (:i, :fac, :refuge..)
        $T(p, i) = new(Symbol(p), Symbol(i))
    end
    ))
end

# Reconstruct original input.
original(a::BasalArg) = Symbol("$(a.p)_$(a.i)")
original(a::ParmIntNestedArg) = (a.p, a.i)
original(a::IntParmNestedArg) = (a.i, a.p)
reorder(::Type{ParmIntNestedArg}) = (a, b) -> (a, b)
reorder(::Type{IntParmNestedArg}) = (a, b) -> (b, a)

# Finality: introduce into error messages to make them more useful.
function name(a::MultiplexNetworkArg)
    o = original(a)
    if typeof(o) <: Tuple
        first, nested = o
        "'$nested' within a '$first' argument"
    else
        "'$o' argument"
    end
end
function error(a::MultiplexNetworkArg, b::MultiplexNetworkArg)
    parm = pstandard(a.p)
    int = istandard(a.i)
    throw(AliasingError(
        "Ambiguous or redundant specification in MultiplexNetwork: " *
        "$parm value for $int interaction is specified as $(name(a)), " *
        "but it has already been specified as $(name(b)). " *
        "Consider removing either one."
    ))
end

function parse_MultiplexNetwork_arguments(foodweb, args)

    S = richness(foodweb)

    # Improve error messages by keeping track of the exact way arguments were input.
    un(T) = Union{Nothing,T}
    ta(T) = Tuple{un(MultiplexNetworkArg),T}

    # Start with empty dicts (all the values we could possibly collect).
    all_parms = MultiplexParametersDict(
        A = InteractionDict{ta(AdjacencyMatrix)}(),
        intensity = InteractionDict{ta(un(AbstractFloat))}(),
        F = InteractionDict{ta(un(Function))}(),
        connectance = InteractionDict{ta(AbstractFloat)}(),
        n_links = InteractionDict{ta(Integer)}(),
        symmetry = InteractionDict{ta(Bool)}(),
    )
    # Check whether a value has already been given.
    already(parm, int) = haskey(all_parms[parm], int)

    # Parse all given arguments to fill them iteratively.
    for (arg, value) in args
        # Expect transversal specifications first, with nested dicts specification.
        found_transversal = false
        for ArgType in [ParmIntNestedArg, IntParmNestedArg]
            ro = reorder(ArgType)
            FirstDict, NestedDict = ro(MultiplexParametersDict, InteractionDict)
            if arg in references(FirstDict)
                found_transversal = true
                try
                    # Scroll sub-arguments within the nested specification.
                    if (!applicable(keys, value) ||
                        (typeof(first(keys(value))) <: Integer) ||
                        !applicable(iterate, value))
                        fname = titlecase(name(FirstDict))
                        nname = name(NestedDict)
                        throw(ArgumentError("$fname argument '$arg' " *
                                            "cannot be iterated as ($nname=value,) pairs."))
                    end
                    for (nested_arg, val) in zip(keys(value), value)
                        parm, int = ro(arg, nested_arg)
                        nested = ArgType(parm, int)
                        if already(parm, int)
                            (ex_arg, _) = all_parms[parm][int]
                            error(nested, ex_arg)
                        end
                        all_parms[parm][int] = (nested, val)
                    end
                catch e
                    if isa(e, AliasingError)
                        throw(AliasingError("During parsing of '$arg' argument: " *
                                            e.message))
                    end
                    rethrow()
                end
            end
            if found_transversal
                break
            end
        end
        if found_transversal
            continue
        end
        # Otherwise, expect basal specification with parameter of the form <parm>_<int>.
        splits = arg_parses(arg)
        if length(splits) == 0
            throw(AliasingError("Could not recognize interaction type or layer parameter " *
                                "within argument name '$arg'."))
        end
        ((parm, int),) = splits #  There may be several ones, but only one meaning.
        basal = BasalArg(parm, int)
        if already(parm, int)
            (ex_arg, _) = all_parms[parm][int]
            error(basal, ex_arg)
        end
        all_parms[parm][int] = (basal, value)
    end

    # Gather/construct adjacency matrices.
    for int in istandards()
        # Special-case trophic layer: already provided with the foodweb.
        if int == :trophic
            for p in [:sym, :A, :L, :C]
                parm = pstandard(p)
                if already(parm, int)
                    (arg, _) = all_parms[parm][int]
                    arg = name(arg)
                    throw(ArgumentError("No need to specify $parm parameter " *
                                        "for the trophic layer ($arg) " *
                                        "since the adjacency matrix " *
                                        "is already specified in the foodweb."))
                end
            end
            continue
        end

        # There are several ways to specify A, forbid ambiguous specifications.
        A_specs = [all_parms[parm][int] for parm in [:A, :C, :L] if already(parm, int)]
        if length(A_specs) > 1
            (x, X), (y, Y) = ((name(arg), pstandard(arg.p)) for (arg, _) in A_specs)
            throw(ArgumentError("Ambiguous specifications for $int matrix adjacency: " *
                                "both $X ($x) and $Y ($y) have been specified. " *
                                "Consider removing one."))
        end
        # Don't specify both symmetry and an explicit matrix.
        if already(:sym, int) && already(:A, int)
            s = name(all_parms[:sym][int][1])
            A = name(all_parms[:A][int][1])
            throw(ArgumentError("Symmetry has been specified " *
                                "for $int matrix adjacency ($s) " *
                                "but the matrix has also been explicitly given ($A). " *
                                "Consider removing symmetry specification."))
        end
        # Don't specify symmetry without a mean to construct a matrix.
        if (already(:sym, int)
            && !already(:L, int)
            && !already(:C, int))
            s = name(all_parms[:sym][int][1])
            c = shortest(:connectance, MultiplexParametersDict)
            n = shortest(:n_links, MultiplexParametersDict)
            throw(ArgumentError("Symmetry has been specified " *
                                "for $int matrix adjacency ($s) " *
                                "but it is unspecified " *
                                "how the matrix is supposed to be generated. " *
                                "Consider specifying connectance " *
                                "(eg. with '$(c)_$(int)') " *
                                "or the number of desired links " *
                                "(eg. with '$(n)_$(int)')."))
        end
        if !already(:A, int)
            # The matrix needs to be constructed.
            sym = (already(:symmetry, int) ?
                   all_parms[:sym][int][2] : defaults[:sym][int])
            # Pick the right functions.
            potential_links = eval(Symbol("potential_$(int)_links"))
            if already(:connectance, int)
                A = nontrophic_adjacency_matrix(
                    foodweb,
                    potential_links,
                    all_parms[:conn][int][2]::AbstractFloat;
                    symmetric = sym
                )
            elseif already(:n_links, int)
                A = nontrophic_adjacency_matrix(
                    foodweb,
                    potential_links,
                    all_parms[:L][int][2]::Integer;
                    symmetric = sym
                )
            else
                # Nothing has actually been specified for this matrix,
                # it'll fall back on default matrix within the next loop.
                continue
            end
            all_parms[:A][int] = (nothing, A)
        else
            # Otherwise it's already here.
            (_, A) = all_parms[:A][int]
            @check_size_is_richness² A S
        end
    end

    # Anything not provided by user is set to default.
    # During this step, drop arguments name informations (eg. (arg, V) -> V).
    for parm in pstandards(), int in istandards()
        if isin(parm, [:C, :L, :symmetry], MultiplexParametersDict)
            # These annex parameters don't need defaults.
            continue
        end
        if !already(parm, int)
            # Missing: read from defaults.
            def = defaults[parm][int]
            if is(parm, :A, MultiplexParametersDict)
                # Special case: this default is a function of the foodweb.
                def = def(foodweb)
            end
            all_parms[parm][int] = (nothing, def)
        end
    end

    # Ready for use.
    all_parms

end
