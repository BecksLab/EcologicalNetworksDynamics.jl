#### Multiplex network objects ####
"""
    Layer(A::SparseMatrixCSC{Bool,Int64}, intensity::Union{Nothing,Float64})

A `Layer` of an interaction type contains
two pieces of information concerning this interaction:
- `A`: where the interactions occur given by the adjacency matrix
- `intensity`: the intensity of the interaction
- `f`: the functional form of the non-trophic effect on the adequate parameter

The intensity is only defined for non-trophic interactions and is set to `nothing` for
trophic interactions.
"""
mutable struct Layer
    A::AdjacencyMatrix
    intensity::Union{Nothing,Float64}
    f::Union{Nothing,Function}
end

mutable struct MultiplexNetwork <: EcologicalNetwork
    trophic_layer::Layer
    competition_layer::Layer
    facilitation_layer::Layer
    interference_layer::Layer
    refuge_layer::Layer
    M::Vector{Float64}
    species::Vector{String}
    metabolic_class::Vector{String}
end

"""
    MultiplexNetwork(
        foodweb::FoodWeb;
        l_competition=0,
        l_facilitation=0,
        l_interference=0,
        l_refuge=0,
        c_competition=0.0,
        c_facilitation=0.0,
        c_interference=0.0,
        c_refuge=0.0,
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
        r0=1.0,
        nti_symmetry=Dict(:competition => true, :facilitation => false,
            :interference => true, :refuge => false)
    )

Build the `MultiplexNetwork` from a [`FoodWeb`](@ref).
A multiplex is composed of a `trophic_layer` and several non-trophic [`Layer`](@ref)
(`competition_layer`, `facilitation_layer`, `interference_layer` and `refuge_layer`).
The `trophic_layer` is given by the [`FoodWeb`](@ref) and, by default,
the non-trophic layers are assumed to be empty.
To fill them 3 methods are possible.

# Fill non-trophic layers

First you can provide a number of links.
For instance to have two facilitation links you can specify `l_facilitation=2`.

```jldoctest 1
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # 2 producers and 1 consumer

julia> MultiplexNetwork(foodweb, l_facilitation=2)
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 2 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

Secondly, you can provide a connectance.
For instance, to fill as much as possible the competition layer you can specify
`c_competition=1.0`.

```jldoctest 1
julia> MultiplexNetwork(foodweb, c_competition=1.0)
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 2 links
  facilitation_layer: 0 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

Lastly, you can provide a custom adjacency matrix.
For instance, to fill the interference layer
according to your custom adjacency matrix you can specify this matrix to `A_interference`.

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]); # 2 consumers feeding on producer 1

julia> MultiplexNetwork(foodweb, A_interference=[0 0 0; 0 0 1; 0 1 0])
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 0 links
  interference_layer: 2 links
  refuge_layer: 0 links
```

# Set non-trophic intensity

The intensities of non-trophic interactions is governed by the four arguments:
- `c0` for competition
- `f0` for facilitation
- `i0` for interference
- `r0` for refuge

By default all intensities are set to `1.0`.
However, they can be easily modified by specifying a value to the adequate argument.
For instance, if you want to set the facilitation intensity to `2.0`.

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # 2 producers and 1 consumer

julia> multiplex_network = MultiplexNetwork(foodweb, l_facilitation=1, f0=2.0);

julia> multiplex_network.facilitation_layer
Layer(A=AdjacencyMatrix(L=1), intensity=2.0)
```

# Change assumptions about the symmetry of non-trophic interactions

An interaction is said to be symmetric if ``i`` interacts with ``j``
implies ``j`` interacts with ``i``.
In other words, an interaction is symmetric if the adjacency matrix of that interaction
is symmetric.

By default, we assume that:
- competition is symmetric
- facilitation is not symmetric
- interference is symmetric
- refuge is not symmetric

These assumptions can be changed by modifying the `nti_symmetry` dictionnary.

See also [`FoodWeb`](@ref), [`Layer`](@ref).
"""
function MultiplexNetwork(
    foodweb::FoodWeb;
    l_competition=0,
    l_facilitation=0,
    l_interference=0,
    l_refuge=0,
    c_competition=0.0,
    c_facilitation=0.0,
    c_interference=0.0,
    c_refuge=0.0,
    A_competition=spzeros(richness(foodweb), richness(foodweb)),
    A_facilitation=spzeros(richness(foodweb), richness(foodweb)),
    A_interference=spzeros(richness(foodweb), richness(foodweb)),
    A_refuge=spzeros(richness(foodweb), richness(foodweb)),
    c0=1.0,
    f0=1.0,
    i0=1.0,
    r0=1.0,
    f_trophic=nothing,
    f_competition=(x, δx) -> x < 0 ? x : max(0, x * (1 - δx)),
    f_facilitation=(x, δx) -> x * (1 + δx),
    f_interference=nothing,
    f_refuge=(x, δx) -> x / (1 + δx),
    nti_symmetry=Dict(:competition => true, :facilitation => false,
        :interference => true, :refuge => false)
)

    # Create adjacency matrices for each non-trophic interaction
    A = Dict(
        :competition => sparse(A_competition),
        :facilitation => sparse(A_facilitation),
        :interference => sparse(A_interference),
        :refuge => sparse(A_refuge)
    )
    l = Dict(
        :competition => Int64(l_competition),
        :facilitation => Int64(l_facilitation),
        :interference => Int64(l_interference),
        :refuge => Int64(l_refuge)
    )
    c = Dict(
        :competition => Float64(c_competition),
        :facilitation => Float64(c_facilitation),
        :interference => Float64(c_interference),
        :refuge => Float64(c_refuge)
    )
    potential_links = Dict(
        :competition => potential_competition_links,
        :facilitation => potential_facilitation_links,
        :interference => potential_interference_links,
        :refuge => potential_refuge_links
    )
    for nti in [:competition, :facilitation, :interference, :refuge]
        if isempty(A[nti].nzval) # no adjacency matrix has been given
            (l[nti] > 0 && c[nti] > 0.0) && throw(ArgumentError("Should provide a number of
            links OR a connectance for $nti, not both simultaneously."))
            n = l[nti] > 0 ? l[nti] : c[nti] # which arg has been provided by the user?
            A[nti] = nontrophic_adjacency_matrix(foodweb, potential_links[nti], n;
                symmetric=nti_symmetry[nti])
        end
    end

    # Safety checks.
    S = richness(foodweb)
    for A_nti in values(A)
        @check_size_is_richness² A_nti S
    end

    # Information from FoodWeb
    A_trophic = foodweb.A
    M = foodweb.M
    species = foodweb.species
    metabolic_class = foodweb.metabolic_class

    # Building layers
    trophic_layer = Layer(A_trophic, nothing, f_trophic)
    competition_layer = Layer(A[:competition], c0, f_competition)
    facilitation_layer = Layer(A[:facilitation], f0, f_facilitation)
    interference_layer = Layer(A[:interference], i0, f_interference)
    refuge_layer = Layer(A[:refuge], r0, f_refuge)

    # Create the resulting multiplex network
    MultiplexNetwork(
        trophic_layer,
        competition_layer,
        facilitation_layer,
        interference_layer,
        refuge_layer,
        M,
        species,
        metabolic_class
    )
end

function MultiplexNetwork(net::UnipartiteNetwork; kwargs...)
    MultiplexNetwork(FoodWeb(net), kwargs...)
end
#### end ####

#### Display MultiplexNetwork & NonTrophicIntensity ####
"One line [`Layer`](@ref) display."
function Base.show(io::IO, layer::Layer)
    L = count(layer.A)
    intensity = layer.intensity
    print(io, "Layer(A=AdjacencyMatrix(L=$L), intensity=$intensity)")
end

"One line [`MultiplexNetwork`](@ref) display."
function Base.show(io::IO, multiplex_net::MultiplexNetwork)
    S = richness(multiplex_net)
    Lt = count(multiplex_net.trophic_layer.A)
    Lr = count(multiplex_net.refuge_layer.A)
    Lf = count(multiplex_net.facilitation_layer.A)
    Li = count(multiplex_net.interference_layer.A)
    Lc = count(multiplex_net.competition_layer.A)
    print(io, "MultiplexNetwork(S=$S, Lt=$Lt, Lf=$Lf, Lc=$Lc, Lr=$Lr, Li=$Li)")
end

"Multiline [`MultiplexNetwork`](@ref) display."
function Base.show(io::IO, ::MIME"text/plain", multiplex_net::MultiplexNetwork)

    # Specify parameters
    S = richness(multiplex_net)
    Lt = count(multiplex_net.trophic_layer.A)
    Lc = count(multiplex_net.competition_layer.A)
    Lf = count(multiplex_net.facilitation_layer.A)
    Li = count(multiplex_net.interference_layer.A)
    Lr = count(multiplex_net.refuge_layer.A)

    # Display output
    println(io, "MultiplexNetwork of $S species:")
    println(io, "  trophic_layer: $Lt links")
    println(io, "  competition_layer: $Lc links")
    println(io, "  facilitation_layer: $Lf links")
    println(io, "  interference_layer: $Li links")
    print(io, "  refuge_layer: $Lr links")
end
#### end ####

#### List potential interactions ####
"""
    potential_facilitation_links(foodweb::FoodWeb)

Find possible facilitation links.
Facilitation links can only occur from any species to a plant.
"""
function potential_facilitation_links(foodweb::FoodWeb)
    S = richness(foodweb)
    [(i, j) for i in (1:S), j in producers(foodweb) if i != j] # i --facilitates-> j
end

"""
    potential_competition_links(foodweb::FoodWeb)

Find possible competition links.
Competition links can only occur between two sessile species (producers).
"""
function potential_competition_links(foodweb::FoodWeb)
    prod = producers(foodweb)
    [(i, j) for i in prod, j in prod if i != j] # i <-competes-> j
end

"""
    potential_refuge_links(foodweb::FoodWeb)

Find possible refuge links.
Refuge links can only occur from a sessile species (producer) to a prey.
"""
function potential_refuge_links(foodweb::FoodWeb)
    [(i, j) for i in producers(foodweb), j in preys(foodweb) if i != j]
end

"""
    potential_interference_links(foodweb::FoodWeb)

Find possible interference links.
Interference liks can only occur between two predators sharing at least one prey.
"""
function potential_interference_links(foodweb::FoodWeb)
    preds = predators(foodweb)
    [(i, j) for i in preds, j in preds if i != j && share_prey(i, j, foodweb)]
end

"Adjacency matrix of potential links given by the `potential_links` function in `net`."
function A_nti_full(net::EcologicalNetwork, potential_links::Function)
    foodweb = convert(FoodWeb, net)
    S = richness(foodweb)
    potential_links = potential_links(foodweb)
    A = spzeros((S, S))
    for (i, j) in potential_links
        A[i, j] = 1
    end
    A
end

"""
    A_competition_full(net)

Adjacency matrix of all possible competition links in the network `net`.

# Example
```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]); # 2 producers

julia> A_competition_full(foodweb)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅   1.0
 1.0   ⋅
```

See also [`A_interference_full`](@ref),
[`A_facilitation_full`](@ref),
[`A_refuge_full`](@ref).
"""
function A_competition_full(net)
    A_nti_full(net, potential_competition_links)
end

"""
    A_facilitation_full(net)

Adjacency matrix of all possible facilitation links in the network `net`.

# Example
```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]); # 2 producers

julia> A_facilitation_full(foodweb)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅   1.0
 1.0   ⋅
```

See also [`A_competition_full`](@ref),
[`A_interference_full`](@ref),
[`A_refuge_full`](@ref).
"""
function A_facilitation_full(net)
    A_nti_full(net, potential_facilitation_links)
end

"""
    A_interference_full(net)

Adjacency matrix of all possible interference links in the network `net`.

# Example
```jldoctest
julia> foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]); # 2 consumers eating producer 1

julia> A_interference_full(foodweb)
3×3 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅    ⋅    ⋅
  ⋅    ⋅   1.0
  ⋅   1.0   ⋅
```

See also [`A_competition_full`](@ref),
[`A_facilitation_full`](@ref),
[`A_refuge_full`](@ref).
"""
function A_interference_full(net)
    A_nti_full(net, potential_interference_links)
end

"""
    A_refuge_full(net)

Adjacency matrix of all possible refuge links in the network `net`.

# Example
```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 0 0]); # consumer 3 eats producer 1

julia> A_refuge_full(foodweb)
3×3 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅    ⋅    ⋅
 1.0   ⋅    ⋅
  ⋅    ⋅    ⋅
```

See also [`A_competition_full`](@ref),
[`A_interference_full`](@ref),
[`A_facilitation_full`](@ref).
"""
function A_refuge_full(net)
    A_nti_full(net, potential_refuge_links)
end
#### end ####

#### Sample potential interactions ####
"""
    draw_asymmetric_links(potential_links, L::Integer)

Draw randomly `L` links from the list of `potential_links`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    @check_is_between L 0 Lmax
    sample(potential_links, L, replace=false)
end

"""
    draw_asymmetric_links(potential_links, C::AbstractFloat)

Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, C::AbstractFloat)
    @check_is_between C 0 1
    Lmax = length(potential_links)
    L = round(Int64, C * Lmax)
    draw_asymmetric_links(potential_links, L)
end

"""
    draw_symmetric_links(potential_links, L::Integer)

Draw randomly `L` links from the list of `potential_links`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    @check_is_between L 0 Lmax
    @check_is_even L
    @check_is_even Lmax
    potential_links = asymmetrize(potential_links)
    potential_links = sample(potential_links, L ÷ 2, replace=false)
    symmetrize(potential_links)
end

"""
    draw_symmetric_links(potential_links, C::AbstractFloat)

Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, C::AbstractFloat)
    @check_is_between C 0 1
    Lmax = length(potential_links)
    L = C * Lmax
    L = 2 * round(Int64, L / 2) # round to an even number
    draw_symmetric_links(potential_links, L)
end

"""
    asymmetrize(V)

Remove duplicate tuples from a symmetric vector of tuples.
A vector `V` of tuples is said symmetric ⟺ ((i,j) ∈ `V` ⟺ (j,i) ∈ `V`).
The tuple that has the 1st element inferior to its 2nd element is kept
i.e. if i < j (i,j) is kept, and (j,i) otherwise.

See also [`symmetrize`](@ref).
"""
function asymmetrize(V)
    [(i, j) for (i, j) in V if i < j]
end

"""
    symmetrize(V)

Add symmetric tuples from an asymmetric vector of tuples.
A vector `V` of tuples is said asymmetric ⟺ ((i,j) ∈ `V` ⇒ (j,i) ∉ `V`).

See also [`asymmetrize`](@ref).
"""
function symmetrize(V)
    vcat(V, [(j, i) for (i, j) in V])
end
#### end ####

#### Generate the realized links ####
"""
    nontrophic_adjacency_matrix(
        foodweb::FoodWeb,
        find_potential_links::Function,
        n;
        symmetric=false)

Generate a non-trophic adjacency matrix
given the function finding potential links (`find_potential_links`)
and `n` which is interpreted as a number of links if `n:<Integer`
or as a connectance if `n:<AbstractFloat`.

See also [`potential_competition_links`](@ref), [`potential_facilitation_links`](@ref),
[`potential_interference_links`](@ref), [`potential_refuge_links`](@ref).
"""
function nontrophic_adjacency_matrix(
    foodweb::FoodWeb,
    find_potential_links::Function,
    n;
    symmetric=false
)
    S = richness(foodweb)
    A = spzeros(Bool, S, S)
    potential_links = find_potential_links(foodweb)
    draw_links = symmetric ? draw_symmetric_links : draw_asymmetric_links
    realized_links = draw_links(potential_links, n)
    for (i, j) in realized_links
        A[i, j] = 1
    end
    A
end
#### end ####
