# Small functions useful for the whole package

#### Conversion between network types ####
"""
Convert a [`MultiplexNetwork`](@ref) to a [`FoodWeb`](@ref).
The convertion consists in removing the non-trophic layers of the multiplex network.
"""
function Base.convert(::Type{FoodWeb}, net::MultiplexNetwork)
    FoodWeb(net.layers[:trophic].A, net.species, net.M, net.metabolic_class, "unspecified")
end

"""
Convert a [`FoodWeb`](@ref) to its `UnipartiteNetwork` equivalent.
"""
Base.convert(::Type{UnipartiteNetwork}, fw::FoodWeb) = UnipartiteNetwork(fw.A, fw.species)
### end ####

"""
    fill_sparsematrix(scalar, template_matrix)

Return a matrix filled with a constant (`scalar`) for indexes where the value of the
`template_matrix` is non-zero.

# Examples

```jldoctest
julia> template_matrix = ones(2, 2);

julia> BEFWM2.fill_sparsematrix(10, template_matrix)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 10.0  10.0
 10.0  10.0

julia> template_matrix[1, 1] = 0;

julia> BEFWM2.fill_sparsematrix(10, template_matrix)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 3 stored entries:
   ⋅   10.0
 10.0  10.0
```
"""
function fill_sparsematrix(x, template)
    out = spzeros(size(template))
    nzind = findall(!iszero, template)
    out[nzind] .= x
    out
end

"""
    n_links(network)

Compute the number of links of a network.
If the argument is an adjacency matrix or a [`Layer`](@ref),
then an integer corresponding to the number of links (i.e. 1s) is returned.
If the argument is a [`FoodWeb`](@ref),
then an integer corresponding to the number of trophic links is returned.
If the argument is a [`MultiplexNetwork`](@ref),
then a dictionnary is returned where `Dict[:interaction_type]` contains
the number of links of the selected interactions

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # food chain of length 3 (2 links)

julia> n_links(foodweb) == n_links(foodweb.A) == 2
true

julia> multi_net = MultiplexNetwork(foodweb; L_facilitation = 1); # + 1 facilitation link

julia> n_links(multi_net)
BEFWM2.InteractionDict{Int64} with 5 entries:
  :trophic      => 2
  :facilitation => 1
  :competition  => 0
  :refuge       => 0
  :interference => 0
```
"""
n_links(A::AdjacencyMatrix) = count(A)
n_links(foodweb::FoodWeb) = n_links(foodweb.A)
n_links(U::UnipartiteNetwork) = n_links(U.edges)
n_links(layer::Layer) = n_links(layer.A)
function n_links(multi_net::MultiplexNetwork)
    links = InteractionDict(;
        trophic = 0,
        competition = 0,
        facilitation = 0,
        interference = 0,
        refuge = 0,
    )
    for (interaction_name, layer) in multi_net.layers
        links[interaction_name] = n_links(layer)
    end
    links
end

"""
Return the adjacency matrix of the trophic interactions.
"""
get_trophic_adjacency(net::FoodWeb) = net.A
get_trophic_adjacency(net::MultiplexNetwork) = net.layers[:trophic].A
