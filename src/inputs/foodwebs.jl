#=
Generating FoodWeb objects
=#

#### Type definition and FoodWeb functions ####
const AdjacencyMatrix = SparseMatrixCSC{Bool,Int64} # alias for comfort

abstract type EcologicalNetwork end
mutable struct FoodWeb <: EcologicalNetwork
    A::AdjacencyMatrix
    species::Vector{String}
    M::Vector{Real}
    metabolic_class::Vector{String}
    method::String
end

"""
    FoodWeb(
        A::AbstractMatrix;
        species::Vector{String} = default_speciesid(A),
        Z::Real = 1,
        M::Vector{<:Real} = compute_mass(A, Z),
        metabolic_class::Vector{String} = default_metabolic_class(A),
        method::String = "unspecified",
    )

# Generate a `FoodWeb` from an adjacency matrix 

This is the most direct way to generate a `FoodWeb`.
You only need to provide and adjacency matrix filled with 0s and 1s,
that respectively indicate the absence (presence) of an interaction 
between the corresponding species pair. 
For instance `A = [0 0; 1 0]` corresponds to a system of 2 species
in which species 2 eats species 1.

```jldoctest
julia> FoodWeb([0 0; 1 0])
FoodWeb of 2 species:
  A: sparse matrix with 1 links
  M: [1.0, 1.0]
  metabolic_class: 1 producers, 1 invertebrates, 0 vertebrates
  method: unspecified
  species: [s1, s2]
```

You can also provide optional arguments e.g. change the species names.

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0], species=["plant", "herbivore"]);

julia> foodweb.species == ["plant", "herbivore"]
true
```

# Generate a `FoodWeb` from a structural model

For larger communities it can be convenient to rely on a structural model.
The structural model implemented are: 
`nichemodel(S; C)`, `cascademodel(S; C)`, nestedhierarchymodel(S; C) and
`mpnmodel(S; C, p_forbidden)`.

To generate a model with one of these model you have to follow this syntax:
`FoodWeb(model_name, model_arguments, optional_FoodWeb_arguments)`.

For instance: 

```jldoctest
julia> foodweb = FoodWeb(nichemodel, 20, C = 0.1, Z = 50);

julia> richness(foodweb) # the FoodWeb of 20 sp. has been well generated
20

julia> foodweb.method == "nichemodel"
true 
```

# Generate a `FoodWeb` from a `UnipartiteNetwork`

Lastly, EcologicalNetworkDynamics.jl has been designed to interact nicely 
with EcologicalNetworks.jl. 
Thus you can also create a `FoodWeb` from a `UnipartiteNetwork`

```jldoctest
julia> uni_net = cascademodel(10, 0.1); # generate a UnipartiteNetwork 

julia> foodweb = FoodWeb(uni_net);

julia> foodweb.A == uni_net.edges # same adjacency matrices
true
```

# `FoodWeb` struct 
    
The function returns a `FoodWeb` which is a collection of the following fields:

- `A` the adjacency matrix
- `species` the vector of species identities
- `M` the vector of species body mass
- `metabolic_class` the vector of species metabolic classes
- `method` describes which model (e.g. niche model) was used to generate `A`
    if no model has been used `method="unspecified"`

See also [`MultiplexNetwork`](@ref).
"""
function FoodWeb(
    A::AbstractMatrix;
    species::Vector{String} = default_speciesid(A),
    Z::Real = 1,
    M::Vector{<:Real} = compute_mass(A, Z),
    metabolic_class::Vector{String} = default_metabolic_class(A),
    method::String = "unspecified",
)
    S = richness(A)
    @check_size_is_richness² A S
    @check_equal_richness length(species) S
    clean_metabolic_class!(metabolic_class, A)
    FoodWeb(sparse(A), species, M, metabolic_class, method)
end

function FoodWeb(
    uni_net::UnipartiteNetwork;
    Z::Real = 1,
    M::AbstractVector = compute_mass(uni_net.edges, Z),
    metabolic_class::Vector{String} = default_metabolic_class(uni_net.edges),
    method::String = "unspecified",
)
    is_from_mangal = isa(uni_net.S, Vector{Mangal.MangalNode})
    species = is_from_mangal ? [split(string(s), ": ")[2] for s in uni_net.S] : uni_net.S
    A = sparse(uni_net.edges)
    FoodWeb(A, species, M, metabolic_class, method)
end

function FoodWeb(
    model::Function,
    S = nothing;
    C = nothing,
    p_forbidden = nothing,
    Z::Real = 1,
    M::Union{Nothing,AbstractVector} = nothing,
)

    uni_net = model_foodweb(model, S, C, p_forbidden)
    A = uni_net.edges
    species = uni_net.S
    metabolic_class = default_metabolic_class(A)
    species = default_speciesid(A)
    if isnothing(M)
        M = compute_mass(A, Z)
    end
    method = string(Symbol(model))
    FoodWeb(A, species, M, metabolic_class, method)
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

#### Utility functions for generating default values, cleaning some arguments, etc.
"Does the user want to replace 'vertebrates' by 'ectotherm vertebrates'?"
function replace_vertebrates!(metabolic_class, vertebrates)
    println("Do you want to replace 'vertebrate' by 'ectotherm vertebrate'? (y or n)")
    answer = readline()
    if answer ∈ ["y", "Y", "yes", "Yes", "YES"]
        replace = true
    elseif answer ∈ ["n", "N", "no", "No", "NO"]
        replace = false
    else
        throw(ErrorException("Invalid answer. Please enter yes (y) or no (n)."))
    end
    if replace
        metabolic_class[vertebrates] .= "ectotherm vertebrate"
    end
end

"Check that provided metabolic classes are valid."
function clean_metabolic_class!(metabolic_class, A)
    # Check that producers are identified as such. If not correct and send a warning.
    prod = producers(A)
    are_producer_valid = all(metabolic_class[prod] .== "producer")
    are_producer_valid ||
        @warn "You provided a metabolic class for basal species: replaced by 'producer'."
    metabolic_class[prod] .= "producer"

    # Replace 'vertebrate' by 'ectotherm vertebrate' if user accept. 
    vertebrates = (1:richness(A))[lowercase.(metabolic_class).=="vertebrate"]
    isempty(vertebrates) || replace_vertebrates!(metabolic_class, vertebrates)

    # Check that metabolic class are valid.
    metabolic_class .= lowercase.(metabolic_class)
    valid_class = ["producer", "ectotherm vertebrate", "invertebrate"]
    are_class_valid = [class ∈ valid_class for class in metabolic_class]
    all(are_class_valid) || throw(
        ArgumentError(
            "An invalid metabolic class has been given, class should be in $valid_class.",
        ),
    )
end

compute_mass(A, Z) = Z .^ (trophic_levels(A) .- 1)

default_speciesid(A) = ["s$i" for i in 1:richness(A)]

function default_metabolic_class(A)
    metabolic_class = repeat(["invertebrate"], richness(A))
    metabolic_class[producers(A)] .= "producer"
    metabolic_class
end

function model_foodweb(model, args...)
    model_name = model |> Symbol |> string
    implemented_models = ["nichemodel", "nestedhierarchymodel", "cascademodel", "mpnmodel"]
    model_name ∈ implemented_models ||
        throw(ArgumentError("Invalid 'model': should be in $implemented_models."))
    args = filter(!isnothing, args) # only keep non-nothing arguments
    model(args...)
end
#### end #### 
