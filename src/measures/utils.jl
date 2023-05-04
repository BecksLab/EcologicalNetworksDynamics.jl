#=
Utility functions for functions in measures
=#

"""
    extract_last_timesteps(solution; idxs = nothing, quiet = false, kwargs...)

Returns the biomass matrix of species x time over the `last` timesteps.

# Arguments:

  - `last`: the number of last timesteps to consider. A percentage can also be also be
    provided as a `String` ending by `%`. Defaulted to 1.
  - `idxs`: vector of species indexes or names. Set to `nothing` by default.
  - `quiet`: ignores warning issue while extracting timesteps before last species extinction

See [`richness`](@ref) for the other arguments. If `idxs` is an integer,
it returns a vector of the species biomass instead of a matrix.

# Examples:

```jldoctest
julia> fw = FoodWeb([0 0; 1 0]);
       p = ModelParameters(fw);
       m = simulate(p, [0.5, 0.5]);
       sim = extract_last_timesteps(m; last = 1, idxs = [2, 1]);
       sim ==
       extract_last_timesteps(m; last = 1, idxs = ["s2", "s1"]) ≈
       [0.219659439; 0.188980349;;]
true

julia> sim1 = extract_last_timesteps(m; last = 1, idxs = [1, 2]);
       sim2 = extract_last_timesteps(m; last = 1, idxs = ["s1", "s2"]);
       sim1 ≈ sim2 ≈ [0.188980349; 0.219659439;;]
true

julia> sim = extract_last_timesteps(m; last = 1, idxs = [2]);
       sim == extract_last_timesteps(m; last = 1, idxs = "s2")
true
```
"""
function extract_last_timesteps(solution; idxs = nothing, quiet = false, kwargs...)
    last = process_last_timesteps(solution; quiet, kwargs...)
    out = solution[:, end-(last-1):end]

    # Extract species indices:
    idxs = process_idxs(solution; idxs)
    out = out[idxs, :]
    quiet || check_last_extinction(solution; idxs, last)

    deepcopy(out)
end

"""
    process_idxs(solution; idxs = nothing)

Check and sanitize the species indices or names provided (`idxs`). Used in
[`extract_last_timesteps`](@ref) and [`living_species`](@ref).
"""
function process_idxs(solution; idxs = nothing)
    sp = get_parameters(solution).network.species

    if isnothing(idxs)
        idxs = sp
    end

    if idxs isa AbstractString || idxs isa Integer
        idxs = [idxs] # Convert plain values into singleton collections.
    end

    # Handle species names:
    if eltype(idxs) <: AbstractString
        idxs_in = indexin(idxs, sp)
        # Handle missing species
        absent_sp = isnothing.(idxs_in)
        any(absent_sp) && throw(
            ArgumentError("Species $(idxs[absent_sp]) are not found in the network. \
                           Any mispelling?"),
        )
        # Get the index of the species names in solution matrix
        idxs = idxs_in[.!absent_sp]
        # remove Union{nothing, ...}
        idxs = something.(idxs)
    elseif eltype(idxs) <: Integer
        check_bound_idxs = 1 .<= idxs .<= length(sp)
        absent_sp = idxs[findall(.!check_bound_idxs)]
        all(check_bound_idxs) || throw(
            ArgumentError(
                "Cannot extract idxs $(absent_sp) when there are $(length(sp)) species.",
            ),
        )
    else
        throw(ArgumentError("`idxs` should be a vector of integers (species indices) \
                             or strings (species names)"))
    end

    idxs
end

function process_last_timesteps(solution; last = 1, quiet = false)

    n_timesteps = length(solution.t)

    if last isa AbstractString
        endswith(last, "%") ||
            throw(ArgumentError("The `last` argument, when given as a string, \
                                 should end with character '%'"))
        perc = parse(Float64, last[1:(end-1)])
        is_valid_perc = 0.0 < perc <= 100.0
        is_valid_perc ||
            throw(ArgumentError("Cannot extract $(perc)% of the solution's timesteps: \
                                 0% < `last` <= 100% must hold."))
        last = round(Int, n_timesteps * perc / 100)
        (last > 0 || quiet) ||
            @warn("$perc% of $n_timesteps timesteps correspond to $last output lines: \
                   an empty table has been extracted.")
    elseif last isa Integer
        last > 0 || throw(ArgumentError("Cannot extract $last timesteps. \
                                         `last` should be a positive integer."))
    elseif last isa Float64
        throw(ArgumentError("Cannot extract `last` from a floating point number. \
                             Did you mean \"$last%\"?"))
    else
        throw(ArgumentError("Cannot extract timesteps with `last=$last` \
                             of type $(typeof(last)). \
                             `last` should be a positive integer \
                             or a string representing a percentage."))
    end

    last > n_timesteps && throw(
        ArgumentError("Cannot extract $last timesteps from a trajectory solution \
                       with only $(n_timesteps) timesteps. \
                       Consider decreasing the `last` argument value \
                       and/or specifying it as a percentage instead (e.g. `\"10%\"`)."),
    )

    last
end

function check_last_extinction(solution; idxs = nothing, last = 1)
    ext = get_extinction_timesteps(solution; idxs)
    ext_t = ext.extinction_timestep
    n_timesteps = length(solution.t)
    check_last_extinction(n_timesteps; t = ext_t, species = ext.species, last)

end
function check_last_extinction(n_timesteps::Integer; t, species, last)
    extinct = t .!== nothing
    if any(extinct)
        check_last = findall(>(n_timesteps - (last - 1)), t[extinct])
        sp = species[extinct][check_last]
        ts = t[extinct][check_last]
        max = n_timesteps - (maximum(t[extinct]) - 1)
        isempty(check_last) ||
            @warn("With `last` = $last, a table has been extracted with the species $sp, \
                   that went extinct at timesteps = $ts. \
                   Set `last` <= $max to get rid of them.")
    end
end

function get_extinction_timesteps(solution; idxs = nothing)
    idxs = process_idxs(solution; idxs)
    sp = get_parameters(solution).network.species[idxs]
    ext_t = findfirst.(isequal(0), eachrow(solution[idxs, :]))
    extinct = ext_t .!== nothing
    (
        species = sp[extinct],
        idxs = idxs[extinct],
        extinction_timestep = something.(ext_t[extinct]),
    )
end

function get_extinction_timesteps(m::AbstractVector; threshold = 0)
    findfirst(x -> x <= threshold, m)
end

"""
    get_alive_species(solution; idxs = nothing, threshold = 0)

Returns a tuple with species having a biomass above `threshold` at the end of a simulation.

# Examples:

```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]; quiet = true);
       params = ModelParameters(foodweb);
       sim = simulate(params, [0, 0.5]; tmax = 20);
       get_alive_species(sim)
(species = ["s2"], idxs = [2])

julia> sim = simulate(params, [0.5, 0]; tmax = 20);
       get_alive_species(sim)
(species = ["s1"], idxs = [1])

julia> sim = simulate(params, [0.5, 0.5]; tmax = 20);
       get_alive_species(sim)
(species = ["s1", "s2"], idxs = [1, 2])

julia> sim = simulate(params, [0, 0]; tmax = 20);
       get_alive_species(sim)
(species = String[], idxs = Int64[])
```
"""
function get_alive_species(solution; idxs = nothing, threshold = 0)
    idxs = process_idxs(solution; idxs)
    sp = get_parameters(solution).network.species[idxs]
    alive = get_alive_species(solution[idxs, end]; threshold = threshold)
    (species = sp[alive], idxs = idxs[alive])
end

get_extinct_species(m::AbstractVector; threshold = 0) = findall(<=(threshold), m)
get_alive_species(m::AbstractVector; threshold = 0) = findall(>(threshold), m)
