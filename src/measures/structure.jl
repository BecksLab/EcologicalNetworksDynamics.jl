#=
Quantifying food webs structural properties
=#

"Number of species in the network."
richness(net::EcologicalNetwork) = richness(get_trophic_adjacency(net))
richness(A::AbstractMatrix) = size(A, 1)

"Connectance of network: number of links / (number of species)^2"
connectance(A::AbstractMatrix) = sum(A) / richness(A)^2
connectance(foodweb::FoodWeb) = connectance(foodweb.A)

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
isproducer(i, net::MultiplexNetwork) = isproducer(i, net.layers[:trophic].A)

"Return indexes of the producers of the given `network`."
producers(net) = filter(isproducer, net)
producers(A::AbstractMatrix) = (1:richness(A))[all(A .== 0; dims = 2)|>vec]
#### end ####

#### Find predators ####
"Return indexes of the predators of species `i`."
predators_of(i, A::AdjacencyMatrix) = A[:, i].nzind
predators_of(i, net::FoodWeb) = predators_of(i, net.A)
predators_of(i, net::MultiplexNetwork) = predators_of(i, net.layers[:trophic].A)

"Is species `i` of the network (`net`) a predator?"
ispredator(i, A::AdjacencyMatrix) = !isproducer(i, A)
ispredator(i, net::FoodWeb) = ispredator(i, net.A)
ispredator(i, net::MultiplexNetwork) = ispredator(i, net.layers[:trophic].A)

"Return indexes of the predators of the given `network`."
predators(net::EcologicalNetwork) = filter(ispredator, net)
#### end ####

#### Find preys ####
"Return indexes of the preys of species `i`."
preys_of(i, A::AdjacencyMatrix) = A[i, :].nzind
preys_of(i, net::FoodWeb) = preys_of(i, net.A)
preys_of(i, net::MultiplexNetwork) = preys_of(i, net.layers[:trophic].A)

"Is species `i` a prey?"
isprey(i, A::AdjacencyMatrix) = !isempty(A[:, i].nzind)
isprey(i, net::FoodWeb) = isprey(i, net.A)
isprey(i, net::MultiplexNetwork) = isprey(i, net.layers[:trophic].A)

"Return indexes of the preys of the network (`net`)."
preys(net::EcologicalNetwork) = filter(isprey, net)
preys(A::AbstractSparseMatrix) = [i for i in 1:size(A, 1) if !isempty(A[:, i].nzval)]

"Do species `i` and `j` share at least one prey?"
share_prey(i, j, A::AdjacencyMatrix) = !isempty(intersect(preys_of(i, A), preys_of(j, A)))
share_prey(i, j, net::FoodWeb) = share_prey(i, j, net.A)
share_prey(i, j, net::MultiplexNetwork) = share_prey(i, j, net.layers[:trophic].A)
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
number_of_resource(i, net::MultiplexNetwork) = number_of_resource(i, net.layers[:trophic].A)

"Return a vector where element i is the number of resource(s) of species i."
function number_of_resource(net::EcologicalNetwork)
    [number_of_resource(i, net) for i in 1:richness(net)]
end
#### end ####

function _ftl(A::AbstractMatrix)
    if isa(A, AbstractMatrix{Int64})
        A = Bool.(A)
    end
    N = UnipartiteNetwork(A)
    dtp = EcologicalNetworks.fractional_trophic_level(N) #shortest path to producer
    for s in dtp

    end
end

"Trophic level of each species."
function trophic_levels(A::AbstractMatrix)
    A = Bool.(A)
    trophiclvl_dict = trophic_level(UnipartiteNetwork(A))
    trophiclvl_val = trophiclvl_dict |> values |> collect
    trophiclvl_keys = trophiclvl_dict |> keys
    species_idx = parse.(Int64, [split(t, "s")[2] for t in trophiclvl_keys])
    trophiclvl_val[sortperm(species_idx)]
end
trophic_levels(net::EcologicalNetwork) = trophic_levels(get_trophic_adjacency(net))

function massratio(obj::Union{ModelParameters,FoodWeb})

    if isa(obj, ModelParameters)
        M = obj.foodweb.M
        A = obj.foodweb.A
    else
        M = obj.M
        A = obj.A
    end

    Z = mean((M./M')[findall(A)])

    return Z

end
