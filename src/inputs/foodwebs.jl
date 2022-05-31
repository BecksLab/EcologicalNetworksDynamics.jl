#=
Generating FoodWeb objects
=#

#### Type definition ####
"""
    A FoodWeb is a collection of the following fields:

- `A` is the (sparse) interaction matrix of boolean values
- `species` is a vector of species identities
- `M` is a vector of species body mass
- `metabolic_class` is a vector of species metabolic classes
- `method` is a String describing the model (if any) used to generate the food web, but can also contain whatever String users want to input (food web source, etc...)
"""

abstract type EcologicalNetwork end

mutable struct FoodWeb <: EcologicalNetwork
    A::SparseMatrixCSC{Bool,Int64}
    species::Vector{String}
    M::Vector{Real}
    metabolic_class::Vector{String}
    method::String
    function FoodWeb(A, species, M, metabolic_class, method)
        S = size(A, 1)
        isequal(size(A, 1))(size(A, 2)) || throw(ArgumentError("The adjacency matrix should be square"))
        isless(S, length(species)) && throw(ArgumentError("That's too many species... there is more species defined than specified in the adjacency matrix"))
        length(species) < S && throw(ArgumentError("That's too few species... there is less species defined than specified in the adjacency matrix"))
        _cleanmetabolicclass!(metabolic_class, A)
        new(A, species, M, metabolic_class, method)
    end
end
#### end ####

#### Type display ####
"One line FoodWeb display."
function Base.show(io::IO, foodweb::FoodWeb)
    S = richness(foodweb)
    links = count(foodweb.A)
    print(io, "FoodWeb(S=$S, L=$links)")
end

"Multiline FoodWeb display."
function Base.show(io::IO, ::MIME"text/plain", foodweb::FoodWeb)

    # Specify parameters
    S = richness(foodweb)
    links = count(foodweb.A)
    class = foodweb.metabolic_class
    n_p = count(class .== "producer")
    n_i = count(class .== "invertebrate")
    n_v = count(class .== "ectotherm vertebrate")

    # Display output
    println(io, "FoodWeb of $S species:")
    println(io, "  A: sparse matrix with $links links")
    println(io, "  M: " * vector_to_string(foodweb.M))
    println(io, "  metabolic_class: $n_p producers, $n_i invertebrates, $n_v vertebrates")
    println(io, "  method: $(foodweb.method)")
    print(io, "  species: " * vector_to_string(foodweb.species))
end

function vector_to_string(vector)
    length(vector) >= 4 ? long_vector_to_string(vector) : short_vector_to_string(vector)
end

function vector_to_string(vector::T where {T<:SparseVector})
    vector.n >= 4 ? long_vector_to_string(vector) : short_vector_to_string(vector)
end

function short_vector_to_string(short_vector)
    out = "["
    n = length(short_vector)
    n <= 4 || throw(ArgumentError("Vector is too long: should be of length 4 or less."))

    for i in 1:(n-1)
        out *= "$(short_vector[i]), "
    end

    out *= "$(short_vector[end])]"
    out
end

function short_vector_to_string(short_vector::T where {T<:SparseVector})
    out = "["
    n = length(short_vector)
    n <= 4 || throw(ArgumentError("Vector is too long: should be of length 4 or less."))

    for i in 1:(n-1)
        out *= display_spvalue(short_vector[i]) * ", "
    end

    out *= display_spvalue(short_vector[end]) * "]"
    out
end

function long_vector_to_string(long_vector)
    n = length(long_vector)
    n >= 4 || throw(ArgumentError("Vector is too short: should be of length 4 or more."))
    "[$(long_vector[1]), $(long_vector[2]), ..., $(long_vector[end-1]), $(long_vector[end])]"
end

function long_vector_to_string(long_vector::T where {T<:SparseVector})
    n = long_vector.n
    n >= 4 || throw(ArgumentError("Vector is too short: should be of length 4 or more."))
    out₁ = "[$(display_spvalue(long_vector[1])), $(display_spvalue(long_vector[2])), ..., "
    out₂ = "$(display_spvalue(long_vector[end-1])), $(display_spvalue(long_vector[end]))]"
    out₁ * out₂
end

function display_spvalue(value)
    out = value == 0.0 ? "⋅" : "$value"
    out
end
#### end ####

#=
Misc functions for generating default values, cleaning some arguments, etc
=#

function _replacevertebrates!(metabolic_class, id_vertebrates) #User input - does user want to replace vertebrates by ectotherm vertebrates
    print("Do you want to replace vertebrates by ectotherm vertebrates (y or n)?")
    n = readline()
    if n ∈ ["y", "Y", "yes", "Yes", "YES"]
        vertreplace = true
    elseif n ∈ ["n", "N", "no", "No", "NO"]
        vertreplace = false
    else
        ErrorException("Please answer yes (y) or no (n)")
    end
    if vertreplace
        metabolic_class[id_vertebrates] .= "ectotherm vertebrate"
    end
end

function _cleanmetabolicclass!(metabolic_class, A)
    # Check that producers are identified as such / replace and send a warning if not
    id_producers = vec(sum(A, dims=2) .== 0)
    are_producer_valid = all(metabolic_class[id_producers] .== "producer")
    are_producer_valid || @warn "You provided a metabolic class for basal species - replaced by producer"
    metabolic_class[id_producers] .= "producer"
    # Warn that only ectotherm vertebrate have default methods
    id_vertebrates = lowercase.(metabolic_class) .== "vertebrate"
    !any(id_vertebrates) || _replacevertebrates!(metabolic_class, id_vertebrates)
    metabolic_class .= lowercase.(metabolic_class)
    valid_class = ["producer", "ectotherm vertebrate", "invertebrate"]
    is_valid_class = falses(length(metabolic_class))
    for (i, m) in enumerate(metabolic_class)
        is_valid_class[i] = m ∈ valid_class ? true : false
    end
    all(is_valid_class) || @warn "No default methods for metabolic classes outside of producers, invertebrates and ectotherm vertebrates, proceed with caution"
end

function _masscalculation(A, M, Z)
    if isa(M, Nothing)
        if isa(Z, Nothing)
            M = ones(size(A, 1))
        else
            tl = _gettrophiclevels(A)
            M = Z .^ (tl .- 1)
        end
    else
        isa(Z, Nothing) || throw(ArgumentError("You provided both a vector of body mass (M) and a predator-prey body mass ratio (Z), please only provide one or the other"))
    end
    return M
end

function _makespeciesid(A, species)
    species = isa(species, Nothing) ? "s" .* string.(1:size(A, 1)) : species
    return species
end

function _makevertebratevec(A, metabolic_class)
    if isa(metabolic_class, Nothing)
        metabolic_class = repeat(["invertebrate"], size(A, 1))
        isP = vec(sum(A, dims=2) .== 0)
        metabolic_class[isP] .= "producer"
    elseif isa(metabolic_class, String)
        metabolic_class = repeat([metabolic_class], size(A, 1))
        isP = vec(sum(A, dims=2) .== 0)
        metabolic_class[isP] .= "producer"
    end
    return metabolic_class
end

function _modelfoodweb(model, S, C, forbidden, adbm_parameters)
    smodel = string(Symbol(model))
    if smodel ∈ ["nichemodel", "nestedhierarchymodel", "cascademodel"]
        A = model(S, C)
    elseif smodel == "mpnmodel"
        A = model(S, C, forbidden)
    elseif smodel == "adbmodel"
        isa(adbm_parameters, Nothing) && throw(ArgumentError("If using the adbmodel you need to provide either a method to generate parameters or a NamedTuple with the parameters, see the help."))
        if isa(adbm_parameters, Symbol)
            println("Not implemented yet")
        elseif isa(adbm_parameters, NamedTuple)
            println("Not implemented yet")
        else
            println("Not implemented yet")
        end
    else
        throw(ArgumentError("Only models implemented are nichemodel, nestedhierarchymodel, cascademodel and mpnmodel."))
    end
    return A
end

#=
FoodWeb functions
=#

"""
    FoodWeb(A; species, M, metabolic_class, method, Z)

Generate a FoodWeb object using the interaction matrix A. A can be
- an AbstractMatrix{T} where T is either Bool or Int64, with `A[i,j] = true` or `A[i,j] = 1` if i eats j and `false` or `0` otherwise.
- a UnipartiteNetwork (see EcologicalNetworks documentation)

Note that consumers are rows and resources are columns.

Keyword arguments:
- `species`: a Vector{String} of species identities. If `species` is unspecified, species identity are automatically created as "si" where i is species i's number
- `M`: a Vector of species body mass. If unspecified, mass are calculated using `Z` (the consumer-resource body size ratio) and trophic rank
- `metabolic_class`: a vector of species metabolic classes. As of yet, only "producer", "invertebrate" and "ectotherm vertebrate" have default parameters, use another class only if you have the corresponding allometric parameters that you want to input. If you provide a metabolic class other than "producer" for basal species, it will be replaced by "producer"
- `method`: a String specifying the method used to generate the food web, you can use that field to specify the food web source. Default is "unspecified"
- `Z`: A number specifying the predator-prey body mass ratio. If specified, body masses are calculated as `M = Z .^ (trophic_rank .- 1)`

Note: If both `Z` and `M` are unspecified, all species will be attributed a mass of 1.0

# Examples
```julia-repl
julia> A = [
    false true true ;
    false false false ;
    false false false
    ] #exploitative competition motif
julia> FW = FoodWeb(A)
3 species - 2 links.
Method: unspecified
```
"""
function FoodWeb(A::AbstractMatrix{Bool}
    ; species::Union{Nothing,Vector{String}}=nothing, M::Union{Nothing,Vector{T}}=nothing, metabolic_class::Union{Nothing,Vector{String},String}=nothing, method::String="unspecified", Z::Union{Nothing,T}=nothing) where {T<:Real}

    M = _masscalculation(A, M, Z)
    species = _makespeciesid(A, species)
    metabolic_class = _makevertebratevec(A, metabolic_class)

    A = sparse(A)

    return FoodWeb(A, species, M, metabolic_class, method)
end

function FoodWeb(A::AbstractMatrix{Int64}
    ; species::Union{Nothing,Vector{String}}=nothing, M::Union{Nothing,Vector{T}}=nothing, metabolic_class::Union{Nothing,Vector{String},String}=nothing, method::String="unspecified", Z::Union{Nothing,Real}=nothing) where {T<:Real}

    M = _masscalculation(A, M, Z)
    species = _makespeciesid(A, species)
    metabolic_class = _makevertebratevec(A, metabolic_class)

    all([a ∈ [0, 1] for a in A]) || throw(ArgumentError("The adjacency matrix should only contain 0 (no interaction between i and j) and 1 (i eats i)"))
    A = sparse(Bool.(A))

    return FoodWeb(A, species, M, metabolic_class, method)
end

function FoodWeb(A::UnipartiteNetwork
    ; M::Union{Nothing,Vector{T}}=nothing, metabolic_class::Union{Nothing,Vector{String},String}=nothing, method::String="unspecified", Z::Union{Nothing,Real}=nothing) where {T<:Real}

    if isa(A.S, Vector{Mangal.MangalNode})
        species = [split(string(s), ": ")[2] for s in A.S]
    else
        species = A.S
    end
    A = A.edges
    M = _masscalculation(A, M, Z)
    metabolic_class = _makevertebratevec(A, metabolic_class)

    return FoodWeb(A, species, M, metabolic_class, method)
end

"""
    FoodWeb(model, S; C, forbidden, adbm_parameters, species, M, metabolic_class, method, Z)

Generate a `FoodWeb` object using the model specified, with S species. Possible models are the ones implemented in EcologicalNetworks (nichemodel, etc).

Keyword arguments:
- `C`: (Float64) connectance needs to be specified for some models
- `forbidden`: (Float64) probability of forbidden links occurring (for the mpnmodel)
- `adbm_parameters`: NOT IMPLEMENTED YET!!! a NamedTuple with the parameters needed to generate a food web with the Allometric Diet Breadth Model.
- `species`: a Vector{String} of species identities. If `species` is unspecified, species identity are automatically created as "si" where i is species i's number
- `M`: a Vector of species body mass. If unspecified, mass are calculated using `Z` (the consumer-resource body size ratio) and trophic rank
- `metabolic_class`: a vector of species metabolic classes. As of yet, only "producer", "invertebrate" and "ectotherm vertebrate" have default parameters, use another class only if you have the corresponding allometric parameters that you want to input. If you provide a metabolic class other than "producer" for basal species, it will be replaced by "producer"
- `method`: a String specifying the name of the model used
- `Z`: A number specifying the predator-prey body mass ratio. If specified, body masses are calculated as `M = Z .^ (trophic_rank .- 1)`

Note: If both `Z` and `M` are unspecified, all species will be attributed a mass of 1.0

# Examples
```julia-repl
julia> A = [
    false true true ;
    false false false ;
    false false false
    ] #exploitative competition motif
julia> FW = FoodWeb(nichemodel, 10, C = 0.2, Z = 10)
3 species - 2 links.
Method: unspecified
```
"""
function FoodWeb(model::Function, S::Int64
    ; C::Union{Nothing,Float64}=nothing, forbidden::Union{Nothing,Float64}=nothing, adbm_parameters::Union{Nothing,NamedTuple,Symbol}=nothing, species::Union{Nothing,Vector{String}}=nothing, M::Union{Nothing,Vector{T}}=nothing, metabolic_class::Union{Nothing,Vector{String},String}=nothing, method::String="unspecified", Z::Union{Nothing,Real}=nothing) where {T<:Real}

    N = _modelfoodweb(model, S, C, forbidden, adbm_parameters)
    A = N.edges
    species = N.S
    metabolic_class = _makevertebratevec(A, metabolic_class)
    species = _makespeciesid(A, species)
    M = _masscalculation(A, M, Z)
    method = string(Symbol(model))

    return FoodWeb(A, species, M, metabolic_class, method)
end
