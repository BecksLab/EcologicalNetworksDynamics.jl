# Small functions useful for the whole package

#### Overloading Base methods ####
"Filter species of the network (`net`) for which `f(species_index, net) = true`."
Base.filter(f, net::EcologicalNetwork) = filter(i -> f(i, net), 1:richness(net))

"Transform species of the network (`net`) by applying `f` to each species."
Base.map(f, net::EcologicalNetwork) = map(i -> f(i, net), 1:richness(net))
#### end ####

#### Find producers ####
"Is species `i` of the network (`net`) a producer?"
isproducer(i, A::AdjacencyMatrix) = isempty(A[i, :].nzval)
isproducer(i, net::FoodWeb) = isproducer(i, net.A)
isproducer(i, net::MultiplexNetwork) = isproducer(i, net.trophic_layer.A)

"Return indexes of the producers of the given `network`."
producers(net::EcologicalNetwork) = filter(isproducer, net)
#### end ####

#### Find predators ####
"Return indexes of the predators of species `i`."
predators_of(i, A::AdjacencyMatrix) = A[:, i].nzind
predators_of(i, net::FoodWeb) = predators_of(i, net.A)
predators_of(i, net::MultiplexNetwork) = predators_of(i, net.trophic_layer.A)

"Is species `i` of the network (`net`) a predator?"
ispredator(i, A::AdjacencyMatrix) = !isproducer(i, A)
ispredator(i, net::FoodWeb) = ispredator(i, net.A)
ispredator(i, net::MultiplexNetwork) = ispredator(i, net.trophic_layer.A)

"Return indexes of the predators of the given `network`."
predators(net::EcologicalNetwork) = filter(ispredator, net)
#### end ####

#### Find preys ####
"Return indexes of the preys of species `i`."
preys_of(i, A::AdjacencyMatrix) = A[i, :].nzind
preys_of(i, net::FoodWeb) = preys_of(i, net.A)
preys_of(i, net::MultiplexNetwork) = preys_of(i, net.trophic_layer.A)

"Is species `i` a prey?"
isprey(i, A::AdjacencyMatrix) = !isempty(A[:, i].nzind)
isprey(i, net::FoodWeb) = isprey(i, net.A)
isprey(i, net::MultiplexNetwork) = isprey(i, net.trophic_layer.A)

"Return indexes of the preys of the network (`net`)."
preys(net::EcologicalNetwork) = filter(isprey, net)
preys(A::AbstractSparseMatrix) = [i for i in 1:size(A, 1) if !isempty(A[:, i].nzval)]

"Do species `i` and `j` share at least one prey?"
share_prey(i, j, A::AdjacencyMatrix) = !isempty(intersect(preys_of(i, A), preys_of(j, A)))
share_prey(i, j, net::FoodWeb) = share_prey(i, j, net.A)
share_prey(i, j, net::MultiplexNetwork) = share_prey(i, j, net.trophic_layer.A)
#### end ####

#### Find verterbrates & invertebrates ####
"Is species `i` a ectotherm vertebrate?"
isvertebrate(i, net::EcologicalNetwork) = net.metabolic_class[i] == "ectotherm vertebrate"

"Is species `i` a invertebrate?"
isinvertebrate(i, net::EcologicalNetwork) = net.metabolic_class[i] == "invertebrate"

"Return indexes of the vertebrates of the network (`net`)."
vertebrates(net::EcologicalNetwork) = filter(isvertebrate, net)

"Return indexes of the invertebrates of the network (`net`)."
invertebrates(net::EcologicalNetwork) = filter(isinvertebrate, net)
#### end ####

#### Number of resources ####
"Number of resource species `i` is feeding on."
number_of_resource(i, A::AdjacencyMatrix) = length(A[i, :].nzval)
number_of_resource(i, net::FoodWeb) = number_of_resource(i, net.A)
number_of_resource(i, net::MultiplexNetwork) = number_of_resource(i, net.trophic_layer.A)

"Return a vector where element i is the number of resource(s) of species i."
function number_of_resource(net::EcologicalNetwork)
    [number_of_resource(i, net) for i in 1:richness(net)]
end
#### end ####

#### Macros ####
"Check that `var` is lower or equal than `max`."
macro check_lower_than(var, max)
    :(
        if $(esc(var)) > $max
            line1 = $(string(var)) * " should be lower or equal to $($max).\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) > $($max)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

"Check that `var` is greater or equal than `min`."
macro check_greater_than(var, min)
    :(
        if $(esc(var)) < $min
            line1 = $(string(var)) * " should be greater or equal to $($min).\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) < $($min)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

"Check that `var` is between `min` and `max` (bounds included)."
macro check_between(var, min, max)
    :(
        if !($min <= $(esc(var)) <= $max)
            line1 = $(string(var)) * " should be between $($min) and $($max).\n"
            line2_1 = "  Evaluated: " * $(string(var)) * " = "
            line2_2 = "$($(esc(var))) ∉ [$($min),$($max)]"
            throw(ArgumentError(line1 * line2_1 * line2_2))
        end
    )
end

"Check that `var` takes one value of the vector `values`."
macro check_in(var, values)
    :(
        if $(esc(var)) ∉ $values
            line1 = $(string(var)) * " should be in $($values) \n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ $($values)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

macro check_in_one_or_richness(var, S)
    :(
        if $(esc(var)) ∉ [1, $(esc(S))]
            line1 = $(string(var)) * " should be in [1, richness].\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ [1, richness].\n"
            line3 = "  Here the species richness is $($(esc(S)))."
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end 

"Check that `mat` has a size `size`."
macro check_size(mat, size)
    :(
        if size($(esc(mat))) != $size
            line1 = $(string(mat)) * " should be of size $($size) \n"
            line2_1 = "  Evaluated: size(" * $(string(mat)) * ") = "
            line2_2 = "$(size($(esc(mat)))) != $($size)"
            throw(ArgumentError(line1 * line2_1 * line2_2))
        end
    )
end
#### end ####

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
    out_matrix
end

"Number of links of an adjacency matrix."
function links(A::AdjacencyMatrix)
    count(A)
end

"Return the adjacency matrix of the trophic interactions."
get_trophic_adjacency(net::FoodWeb) = net.A
get_trophic_adjacency(net::MultiplexNetwork) = net.trophic_layer.A
