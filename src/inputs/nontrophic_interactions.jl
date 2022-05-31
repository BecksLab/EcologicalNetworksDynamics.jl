#### Multiplex network objects ####
const AdjacencyMatrix = SparseMatrixCSC{Float64,Int}

mutable struct MultiplexNetwork <: EcologicalNetwork
    trophic::AdjacencyMatrix
    facilitation::AdjacencyMatrix
    competition::AdjacencyMatrix
    refuge::AdjacencyMatrix
    interference::AdjacencyMatrix
    bodymass::Vector{Float64}
    species_id::Vector{String}
end

"Build the [`MultiplexNetwork`](@ref) from the [`FoodWeb`](@ref)."
function MultiplexNetwork(
    foodweb::FoodWeb;
    C_facilitation=0.0,
    C_competition=0.0,
    C_refuge=0.0,
    C_interference=0.0,
    facilitation=nontrophic_matrix(foodweb, potential_facilitation_links,
        C_facilitation, symmetric=false),
    competition=nontrophic_matrix(foodweb, potential_competition_links,
        C_competition, symmetric=true),
    refuge=nontrophic_matrix(foodweb, potential_refuge_links,
        C_refuge, symmetric=false),
    interference=nontrophic_matrix(foodweb, potential_interference_links,
        C_interference, symmetric=true)
)

    # Safety checks.
    S = richness(foodweb)
    size(facilitation) == (S, S) || throw(ArgumentError("Adjacency matrix should be of
        size (S,S) with S the species richness."))
    size(competition) == (S, S) || throw(ArgumentError("Adjacency matrix should be of
        size (S,S) with S the species richness."))
    size(refuge) == (S, S) || throw(ArgumentError("Adjacency matrix should be of
        size (S,S) with S the species richness."))
    size(interference) == (S, S) || throw(ArgumentError("Adjacency matrix should be of
        size (S,S) with S the species richness."))
    #!Todo: test validity of custom matrices (e.g. facilitation: only prod. are facilitated)

    # Information from FoodWeb.
    trophic = foodweb.A
    bodymass = foodweb.M
    species_id = foodweb.species

    MultiplexNetwork(trophic, sparse(facilitation), sparse(competition),
        sparse(refuge), sparse(interference), bodymass, species_id)
end
#### end ####

#### List potential interactions ####
"Find potential facilitation links."
function potential_facilitation_links(foodweb)
    S = richness(foodweb)
    producers = (1:S)[whoisproducer(foodweb)]
    [(i, j) for i in (1:S), j in producers if i != j] # i facilitated, j facilitating
end

"Find potential competition links."
function potential_competition_links(foodweb)
    S = richness(foodweb)
    producers = (1:S)[whoisproducer(foodweb)]
    [(i, j) for i in producers, j in producers if i != j]
end

"Find potential refuge links."
function potential_refuge_links(foodweb)
    S = richness(foodweb)
    producers = (1:S)[whoisproducer(foodweb)]
    preys = (1:S)[whoisprey(foodweb)]
    [(i, j) for i in producers, j in preys if i != j]
end

"Find potential interference links."
function potential_interference_links(foodweb)
    S = richness(foodweb)
    predators = (1:S)[whoispredator(foodweb)]
    [(i, j) for i in predators, j in predators if i != j && share_prey(foodweb, i, j)]
end
#### end ####

#### Sample potential interactions ####
"""
Draw randomly `L` links from the list of `potential_links`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    L >= 0 || throw(ArgumentError("L too small: should be positive."))
    L <= Lmax || throw(ArgumentError("L too large: should be lower than $Lmax,
    the maximum number of potential interactions."))
    sample(potential_links, L, replace=false)
end

"""
Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, C::AbstractFloat)
    0 <= C <= 1 || throw(ArgumentError("Connectance out of bounds: should be in [0,1]."))
    Lmax = length(potential_links)
    L = round(Int64, C * Lmax)
    draw_asymmetric_links(potential_links, L)
end

"""
Draw randomly `L` links from the list of `potential_links`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    L >= 0 || throw(ArgumentError("L too small: should be positive."))
    L <= Lmax || throw(ArgumentError("L too large: should be lower than $Lmax,
    the maximum number of potential interactions."))
    L % 2 == 0 || throw(ArgumentError("Odd number of links:
    interaction should be symmetric."))
    Lmax % 2 == 0 || throw(ArgumentError("Odd total number of links:
    interaction should be symmetric."))
    potential_links = asymmetrize(potential_links)
    potential_links = sample(potential_links, L ÷ 2, replace=false)
    symmetrize(potential_links)
end

"""
Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, C::AbstractFloat)
    0 <= C <= 1 || throw(ArgumentError("Connectance out of bounds: should be in [0,1]."))
    Lmax = length(potential_links)
    L = C * Lmax
    L = 2 * round(Int64, L / 2) # round to an even number
    draw_symmetric_links(potential_links, L)
end

"""
Remove duplicate tuples from a symmetric vector of tuples.
A vector `V` of tuples is said symmetric ⟺ ((i,j) ∈ `V` ⟺ (j,i) ∈ `V`).
The tuple that has the 1st element inferior to its 2nd element is kept
i.e. if i < j (i,j) is kept, and (j,i) otherwise.
"""
function asymmetrize(V)
    [(i, j) for (i, j) in V if i < j]
end

"""
Add symmetric tuples from an asymmetric vector of tuples.
A vector `V` of tuples is said asymmetric ⟺ ((i,j) ∈ `V` ⇒ (j,i) ∉ `V`).
"""
function symmetrize(V)
    vcat(V, [(j, i) for (i, j) in V])
end
#### end ####

#### Generate the realized links ####
"Generate the non-trophic matrix given the interaction number or connectance."
function nontrophic_matrix(foodweb, potential_links_function, n; symmetric=false)

    # Initialization.
    S = richness(foodweb)
    A = spzeros(S, S)
    potential_links = potential_links_function(foodweb)

    draw_links = symmetric ? draw_symmetric_links : draw_asymmetric_links
    realized_links = draw_links(potential_links, n)

    # Fill matrix with corresponding links.
    for (i, j) in realized_links
        A[i, j] = 1
    end

    A
end
#### end ####
