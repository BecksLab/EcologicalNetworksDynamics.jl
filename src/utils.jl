# Small functions useful for the whole package

#### Conversion between network types ####
"""
Convert a [`MultiplexNetwork`](@ref) to a [`FoodWeb`](@ref).
The convertion consists in removing the non-trophic layers of the multiplex network.
"""
function Base.convert(::Type{FoodWeb}, net::MultiplexNetwork)
    FoodWeb(net.trophic_layer.A, net.species, net.M, net.metabolic_class, "unspecified")
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
julia> template_matrix = ones(2,2);

julia> BEFWM2.fill_sparsematrix(10, template_matrix)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 10.0  10.0
 10.0  10.0

julia> template_matrix[1,1] = 0;

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

"Number of links of an adjacency matrix."
function links(A::AdjacencyMatrix)
    count(A)
end

"Return the adjacency matrix of the trophic interactions."
get_trophic_adjacency(net::FoodWeb) = net.A
get_trophic_adjacency(net::MultiplexNetwork) = net.trophic_layer.A
