#=
Models for producer growth
=#

#### Type definition ####
abstract type ProducerGrowth end

mutable struct LogisticGrowth <: ProducerGrowth
    a::SparseMatrixCSC{Float64,Int64} # relative inter to intra-specific competition between producers
    K::Vector{Union{Nothing,Float64}}
end

mutable struct NutrientIntake <: ProducerGrowth
    n_nutrients::Int64
    turnover::Vector{Float64}
    supply::Vector{Float64}
    concentration::SparseMatrixCSC{Float64}
    half_saturation::Matrix{Union{Nothing,Float64}}
end
#### end ####

#### Type display ####
"""
One line display FunctionalResponse
"""
Base.show(io::IO, model::ProducerGrowth) = print(io, "$(typeof(model))")

"""
Multiline LogisticGrowth display.
"""
function Base.show(io::IO, ::MIME"text/plain", model::LogisticGrowth)
    S = size(model.a, 1)
    println(io, "LogisticGrowth:")
    println(io, "  K - carrying capacity: " * vector_to_string(model.K))
    print(io, "  a - competition: ($S, $S) sparse matrix")
end

"""
Multiline NutrientIntake display.
"""
function Base.show(io::IO, ::MIME"text/plain", model::NutrientIntake)
    println(io, "NutrientIntake - $(model.n_nutrients) nutrients:")
    println(io, "  `turnover` rate: $(model.turnover)")
    println(io, "  `supply` concentrations: " * vector_to_string(model.supply))
    println(io, "  relative `concentration` (n_producers, n_nutrients) sparse matrix")
    print(io, "  `half_saturation` densities: (n_producers, n_nutrients) sparse matrix")
end
#### end ####

#### Methods for building ####
"""
    LogisticGrowth(
        network::EcologicalNetwork;
        a_ii = 1.0,
        a_ij = 0.0,
        a_matrix = nothing,
        K = 1,
        quiet = false,
    )

Create the parameters for the logistic producer growth model.
In the end, the `LogisticGrowth` struct created stores a vector of carrying capacities `K`
and a competition matrix between the producers `a`.

The carrying capacities can be specified via the `K` arguments,
by default they are all set to 1 for the producers and to `nothing` for the consumers.

The competition matrix between can be directly given via the `a_matrix` argument.
Otherwise, one can use the `a_ii` and `a_ij` arguments to generate a competition matrix
whose diagonal elements (intraspecific competition) will be equal to `a_ii`
and off-diagonal elements (interspecific competition) to `a_ij`.
Note that coefficients of this matrix are non-zero only for couple of producers.
By default, we assume that `a_ii = 1` and `a_ij = 0`.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]) # 1 & 2 producers and 3 consumer.
       g = LogisticGrowth(foodweb)
       g.a == [
           1 0 0
           0 1 0
           0 0 0
       ]
true

julia> g.K == [1, 1, nothing]
true

julia> K_cst = 5.0
       g = LogisticGrowth(foodweb; K = K_cst) # Change the default K.
       g.K == [K_cst, K_cst, nothing]
true

julia> K_vec = [1, 2, nothing]
       g = LogisticGrowth(foodweb; K = K_vec) # Can also provide a vector.
       g.K == K_vec
true

julia> g = LogisticGrowth(foodweb; a_ii = 0.5, a_ij = 1.0)
       g.a == [
           0.5 1.0 0.0
           1.0 0.5 0.0
           0.0 0.0 0.0
       ]
true

julia> my_competition_matrix = [
           0.5 1.0 0.0
           1.0 0.5 0.0
           0.0 0.0 0.0
       ]
       g = LogisticGrowth(foodweb; a_matrix = my_competition_matrix, quiet = true)
       g.a == my_competition_matrix
true
```

See also [`ModelParameters`](@ref) and [`NutrientIntake`](@ref).
"""
function LogisticGrowth(
    network::EcologicalNetwork;
    a_ii = 1.0,
    a_ij = 0.0,
    a_matrix = nothing,
    K = 1,
    quiet = false,
)
    S = richness(network)
    isa(K, AbstractVector) || (K = [isproducer(i, network) ? K : nothing for i in 1:S])
    @check_equal_richness length(K) S

    if !isnothing(a_matrix)
        quiet || @info "You provided a competition matrix `a_matrix`, \
        arguments `a_ii` and `a_ij` are being ignored."
    else # Build competition matrix from a_ii and a_ij coefficients.
        a_matrix = spzeros(S, S)
        prods = producers(network)
        for i in prods, j in prods
            a_matrix[i, j] = i == j ? a_ii : a_ij
        end
    end
    @assert size(a_matrix, 1) == size(a_matrix, 2) == S
    non_producer = filter(!isproducer, network)
    if !isempty(non_producer)
        @assert all(a_matrix[non_producer, :] .== 0)
        @assert all(a_matrix[:, non_producer] .== 0)
    end
    LogisticGrowth(a_matrix, K)
end

"""
    NutrientIntake(
        network::EcologicalNetwork;
        n_nutrients = 2,
        turnover = 0.25,
        supply = fill(10.0, n_nutrients),
        concentration = [range(1, 0.5; n_nutrients)],
        half_saturation = 1.0,
    )

Create parameters for the nutrient intake model of producer growths.
These parameters are:

  - the number of nutrients `n_nutrients` (number)
  - the nutrient `turnover` rate (number)
  - the `supply` concentration for each nutrient (vector of length `n_nutrients`)
  - the relative `concentration` of each nutrients in each producers
    (matrix of size (n_producers, n_nutrients))
  - the `half_saturation` densities for each nutrient-producer pair
    (matrix of size (n_producers, n_nutrients))

# Examples

```jldoctest
julia> foodweb = FoodWeb([3 => [1, 2]]); # 3 feeds on 1 and 2.
       ni = NutrientIntake(foodweb) # knights who say..
       ni.n_nutrients == 2 # 2 nutrients by default.
true

julia> ni.turnover == [0.25, 0.25]
true

julia> ni.supply == [10, 10]
true

julia> ni.concentration == [1 0.5; 1 0.5]
true

julia> ni.half_saturation == [1 1; 1 1]
true

julia> ni = NutrientIntake(foodweb; turnover = 1.0)
       ni.turnover == [1.0, 1.0]
true

julia> ni = NutrientIntake(foodweb; n_nutrients = 5)
       ni.n_nutrients == 5
true
```

See also [`ModelParameters`](@ref) and [`ProducerGrowth`](@ref).
"""
function NutrientIntake(
    network::EcologicalNetwork;
    n_nutrients = 2,
    turnover = 0.25,
    supply = fill(10.0, n_nutrients),
    concentration = collect(LinRange(1, 0.5, n_nutrients)),
    half_saturation = 1.0,
)
    0 < turnover <= 1 || throw(ArgumentError("`turnover` rate should be in ]0, 1]."))

    length(supply) == 1 && (supply = fill(supply[1], n_nutrients))
    length(supply) == n_nutrients ||
        throw(ArgumentError("`supply` should be of length 1 or `n_nutrients`."))

    n_producers = length(producers(network))
    concentration_size = size(concentration)
    if concentration_size == () || concentration_size == (1,)
        concentration = fill(concentration[1], n_producers, n_nutrients)
    elseif concentration_size == (n_nutrients,)
        concentration = repeat(concentration, 1, n_producers)'
    elseif concentration_size != (n_producers, n_nutrients)
        throw(
            ArgumentError("`concentration` should be either: a number, \
                          a vector of length 1 or number of producers, \
                          or a matrix of size (number of producer, number of nutrients)."),
        )
    end

    length(turnover) == 1 && (turnover = fill(turnover[1], n_nutrients))
    length(turnover) != n_nutrients &&
        throw(ArgumentError("`turnover` should either be a number, a vector of length 1 \
              or a vector of length `n_nutrients`."))

    half_saturation_size = size(half_saturation)
    if half_saturation_size == () || half_saturation_size == (1,)
        half_saturation = fill(half_saturation[1], n_producers, n_nutrients)
    elseif half_saturation_size == (n_producers,)
        half_saturation = repeat(half_saturation, 1, n_nutrients)
    elseif half_saturation_size != (n_producers, n_nutrients)
        throw(
            ArgumentError("`half_saturation` should be either: a number, \
                          a vector of length 1 or number of producers, \
                          or a matrix of size (number of producer, number of nutrients)."),
        )
    end

    NutrientIntake(n_nutrients, turnover, supply, concentration, half_saturation)
end
#### end ####
