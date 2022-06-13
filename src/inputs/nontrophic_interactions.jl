#### Multiplex network objects ####
mutable struct Layer
    adjacency::AdjacencyMatrix
    intensity::Union{Nothing,Float64}
end

mutable struct MultiplexNetwork <: EcologicalNetwork
    trophic_layer::Layer
    competition_layer::Layer
    facilitation_layer::Layer
    interference_layer::Layer
    refuge_layer::Layer
    bodymass::Vector{Float64}
    species_id::Vector{String}
    metabolic_class::Vector{String}
end

"Build the [`MultiplexNetwork`](@ref) from the [`FoodWeb`](@ref)."
function MultiplexNetwork(
    foodweb::FoodWeb;
    n_competition=0.0,
    n_facilitation=0.0,
    n_interference=0.0,
    n_refuge=0.0,
    A_competition=nontrophic_adjacency_matrix(foodweb, potential_competition_links,
        n_competition, symmetric=true),
    A_facilitation=nontrophic_adjacency_matrix(foodweb, potential_facilitation_links,
        n_facilitation, symmetric=false),
    A_interference=nontrophic_adjacency_matrix(foodweb, potential_interference_links,
        n_interference, symmetric=true),
    A_refuge=nontrophic_adjacency_matrix(foodweb, potential_refuge_links,
        n_refuge, symmetric=false),
    c0=1.0,
    f0=1.0,
    i0=1.0,
    r0=1.0
)

    # Safety checks.
    S = richness(foodweb)
    for A in [A_competition, A_facilitation, A_interference, A_refuge]
        size(A) == (S, S) || throw(ArgumentError("Wrong size $(size(A)):
            adjacency matrix should be of size (S,S) with S the species richness (S=$S)."))
    end
    #!Todo: test validity of custom matrices (e.g. facilitation: only prod. are facilitated)

    # Information from FoodWeb.
    A_trophic = foodweb.A
    bodymass = foodweb.M
    species_id = foodweb.species
    metabolic_class = foodweb.metabolic_class

    # Building layers.
    trophic_layer = Layer(A_trophic, nothing)
    competition_layer = Layer(A_competition, c0)
    facilitation_layer = Layer(A_facilitation, f0)
    interference_layer = Layer(A_interference, i0)
    refuge_layer = Layer(A_refuge, r0)

    # Create the resulting multiplex network.
    MultiplexNetwork(
        trophic_layer,
        competition_layer,
        facilitation_layer,
        interference_layer,
        refuge_layer,
        bodymass,
        species_id,
        metabolic_class
    )
end
#### end ####

#### Display MultiplexNetwork & NonTrophicIntensity ####
"One line [`Layer`](@ref) display."
function Base.show(io::IO, layer::Layer)
    L = count(layer.adjacency)
    intensity = layer.intensity
    print(io, "Layer(adjacency=AdjacencyMatrix(L=$L), intensity=$intensity)")
end

"One line [`MultiplexNetwork`](@ref) display."
function Base.show(io::IO, multiplex_net::MultiplexNetwork)
    S = richness(multiplex_net)
    Lt = count(multiplex_net.trophic_layer.adjacency)
    Lr = count(multiplex_net.refuge_layer.adjacency)
    Lf = count(multiplex_net.facilitation_layer.adjacency)
    Li = count(multiplex_net.interference_layer.adjacency)
    Lc = count(multiplex_net.competition_layer.adjacency)
    print(io, "MultiplexNetwork(S=$S, Lt=$Lt, Lf=$Lf, Lc=$Lc, Lr=$Lr, Li=$Li)")
end

"Multiline [`MultiplexNework`](@ref) display."
function Base.show(io::IO, ::MIME"text/plain", multiplex_net::MultiplexNetwork)

    # Specify parameters
    S = richness(multiplex_net)
    Lt = count(multiplex_net.trophic_layer.adjacency)
    Lc = count(multiplex_net.competition_layer.adjacency)
    Lf = count(multiplex_net.facilitation_layer.adjacency)
    Li = count(multiplex_net.interference_layer.adjacency)
    Lr = count(multiplex_net.refuge_layer.adjacency)

    # Display output
    println(io, "MultiplexNetwork of $S species:")
    println(io, "  trophic_layer: $Lt links")
    println(io, "  competition_layer: $Lc links")
    println(io, "  facilitation_layer: $Lf links")
    println(io, "  interference_layer: $Li links")
    print(io, "  refuge_layer: $Lr links")
end
#### end ####

#### Conversion FoodWeb ↔ MultiplexNetwork ####
import Base.convert

"""
Convert a [`MultiplexNetwork`](@ref) to a [`FoodWeb`](@ref).
The convertion consists in removing the non-trophic layers of the multiplex networks.
"""
function convert(::Type{FoodWeb}, net::MultiplexNetwork)
    FoodWeb(net.trophic_layer.adjacency, species=net.species_id, M=net.bodymass,
        metabolic_class=net.metabolic_class)
end

"""
Convert a [`FoodWeb`](@ref) to a [`MultiplexNetwork`](@ref).
The convertion consists in adding empty non-trophic layers to the foodweb.
"""
function convert(::Type{MultiplexNetwork}, net::FoodWeb)
    MultiplexNetwork(net)
end
### end ####

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
    L >= 0 || throw(ArgumentError("L too small: L=$L whereas L should be positive."))
    L <= Lmax || throw(ArgumentError("L too large:
        L=$L whereas L should be lower or equal to $Lmax,
        the maximum number of potential interactions."))
    sample(potential_links, L, replace=false)
end

"""
Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, C::AbstractFloat)
    0 <= C <= 1 || throw(ArgumentError("Connectance out of bounds:
    C=$C whereas connectance should be in [0,1]."))
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
    L >= 0 || throw(ArgumentError("L too small: L=$L whereas L should be positive."))
    L <= Lmax || throw(ArgumentError("L too large:
        L=$L whereas L should be lower or equal to $Lmax,
        the maximum number of potential interactions."))
    L % 2 == 0 || throw(ArgumentError("Odd number of links (L=$L):
    interaction should be symmetric."))
    Lmax % 2 == 0 || throw(ArgumentError("Odd total number of links (L=$L):
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
    0 <= C <= 1 || throw(ArgumentError("Connectance out of bounds:
        C=$C whereas connectance should be in [0,1]."))
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
function nontrophic_adjacency_matrix(foodweb, find_potential_links, n; symmetric=false)

    # Initialization.
    S = richness(foodweb)
    A = spzeros(Bool, S, S)
    potential_links = find_potential_links(foodweb)

    draw_links = symmetric ? draw_symmetric_links : draw_asymmetric_links
    realized_links = draw_links(potential_links, n)

    # Fill matrix with corresponding links.
    for (i, j) in realized_links
        A[i, j] = 1
    end

    A
end
#### end ####
