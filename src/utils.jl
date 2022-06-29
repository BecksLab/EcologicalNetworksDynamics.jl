# Small functions useful for the whole package

#### Identifying metabolic classes ####
"Helper function called by `whois...` functions (e.g. `whoisproducer`)."
function whois(metabolic_class::String, foodweb::EcologicalNetwork)
    vec(foodweb.metabolic_class .== metabolic_class)
end
"Which species is a producer or not? Return a BitVector."
function whoisproducer(foodweb::EcologicalNetwork)
    whois("producer", foodweb)
end
"Which species is an vertebrate or not? Return a BitVector."
function whoisvertebrate(foodweb::EcologicalNetwork)
    whois("ectotherm vertebrate", foodweb)
end
"Which species is an invertebrate or not? Return a BitVector."
function whoisinvertebrate(foodweb::EcologicalNetwork)
    whois("invertebrate", foodweb)
end

function whoisproducer(A)
    vec(.!any(A, dims=2))
end

function isproducer(foodweb::EcologicalNetwork, i)
    foodweb.metabolic_class[i] == "producer"
end

function whoispredator(foodweb::FoodWeb)
    whoispredator(foodweb.A)
end

function whoispredator(A::AbstractSparseMatrix)
    vec(any(A .> 0, dims=2))
end

function whoisprey(foodweb::FoodWeb)
    whoisprey(foodweb.A)
end

function whoisprey(A::AbstractSparseMatrix)
    vec(any(A .> 0, dims=1))
end

"Are predators `i` and `j` sharing at least one prey?"
function share_prey(foodweb, i, j)
    any(foodweb.A[i, :] .&& foodweb.A[j, :])
end
#### end ####

#### Find consumers and resources of a species ####
function resource(i, foodweb::FoodWeb)
    any.(foodweb.A[i, :])
end

function consumer(i, foodweb::FoodWeb)
    any.(foodweb.A[:, i])
end
#### end #### 

function resourcenumber(consumer, A::AdjacencyMatrix)
    sum(A[consumer, :])
end
function resourcenumber(consumer::Vector, A::AdjacencyMatrix)
    Dict(i => resourcenumber(i, A) for i in unique(consumer))
end
function resourcenumber(consumer::Vector, foodweb::FoodWeb)
    Dict(i => resourcenumber(i, foodweb.A) for i in unique(consumer))
end

"""
    scalar_to_sparsematrix(scalar, template_matrix)

Return a matrix filled with a constant (`scalar`) for indexes where the value of the
`template_matrix` is non-zero.

# Examples

```jldoctest
julia> template_matrix = ones(2,2);

julia> BEFWM2.scalar_to_sparsematrix(10, template_matrix)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 10.0  10.0
 10.0  10.0

julia> template_matrix[1,1] = 0;

julia> BEFWM2.scalar_to_sparsematrix(10, template_matrix)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 3 stored entries:
   ⋅   10.0
 10.0  10.0
```
"""
function scalar_to_sparsematrix(scalar, template_matrix)
    S = size(template_matrix, 1)
    out_matrix = spzeros(S, S)
    nonzero_indexes = findall(!iszero, template_matrix)
    out_matrix[nonzero_indexes] .= scalar
    sparse(out_matrix)
end

"Number of links of an adjacency matrix."
function links(A::AdjacencyMatrix)
    count(A)
end

"Return the adjacency matrix of the trophic interactions."
get_trophic_adjacency(net::FoodWeb) = net.A
get_trophic_adjacency(net::MultiplexNetwork) = net.trophic_layer.A
