#=
Models for producer growth
=#

#### Type definition ####
abstract type ProducerGrowth end

struct LogisticGrowth <: ProducerGrowth
    α::SparseMatrixCSC{Float64,Int64} # relative inter to intra-specific competition between producers
    Kᵢ::Vector{Union{Nothing,Float64}}
end

struct NutrientIntake <: ProducerGrowth
    n::Int64
    D::Real
    Sₗ::Vector{Float64}
    Cₗᵢ::SparseMatrixCSC{Float64}
    Kₗᵢ::Matrix{Union{Nothing,Float64}}
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
    S = size(model.α, 1)
    println(io, "LogisticGrowth:")
    println(io, "  Kᵢ - carrying capacity: " * vector_to_string(model.Kᵢ))
    print(io, "  α - competition: ($S, $S) sparse matrix")
end

"""
Multiline NutrientIntake display.
"""
function Base.show(io::IO, ::MIME"text/plain", model::NutrientIntake)
    println(io, "NutrientIntake - $(model.n) nutrients:")
    println(io, "  D - turnover rate: $(model.D)")
    println(io, "  Sₗ - supply concentrations: " * vector_to_string(model.Sₗ))
    println(io, "  Cₗᵢ - relative contents: (S, n) sparse matrix")
    print(io, "  Kₗᵢ - half sat. densities: (S, n) matrix")
end

#### end ####

#### Methods for building ####
"""
    LogisticGrowth(network, α = nothing, αii = 1.0, αij = 0.0, K = 1.0)

Creates the parameters needed for the logistic producer growth model, these parameters are: 
    - α the competition matrix of dimensions S*S, S being the species number of the network. Set to nothing by default.
    - αii the intracompetition term for all species, 1.0 by default.
    - αij the interspecific (relative to intraspecific) competition term for all species, 0.0 by default.
    - Kᵢ the vector of carrying capacities, set to 1 for all producer by default, meaning that each producer 
    gets its own carrying capacity and that the more producer in the system, the larger the overall carrying capacity.

By default, with intraspecific competition set to unity and interspecific competition set to 0, the competition matrix 
does not affect the system and the model behaves as if where not here. 

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # species 1 & 2 producers, 3 consumer

julia> def = LogisticGrowth(foodweb) # default behavior
LogisticGrowth:
  K - carrying capacity: [1, 1, nothing]
  α - competition: (3, 3) sparse matrix

julia> def.α
3×3 SparseMatrixCSC{Float64, Int64} with 2 stored entries:
 1.0   ⋅    ⋅ 
  ⋅   1.0   ⋅ 
  ⋅    ⋅    ⋅ 

julia> def.Kᵢ
3-element Vector{Union{Nothing, Real}}:
 1
 1
  nothing

julia> K_system = 10 #set system carrying capacity to 10
10

julia> Kᵢ = K_system/length(producers(foodweb))
5.0

julia> LogisticGrowth(foodweb; K = Kᵢ).Kᵢ # change the default value for producer carrying capacity
3-element Vector{Union{Nothing, Real}}:
 5.0
 5.0
  nothing

julia> LogisticGrowth(foodweb; K = [1, 2, nothing]).Kᵢ # can also provide a vector
3-element Vector{Union{Nothing, Real}}:
 1
 2
  nothing

julia> LogisticGrowth(foodweb; αii = 0.5, αij = 1.0).α
3×3 SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 0.5  1.0   ⋅ 
 1.0  0.5   ⋅ 
  ⋅    ⋅    ⋅

julia> #pass a matrix
julia> my_α = [0.5 1.0 0; 1.0 0.5 0; 0 0 0]
3×3 Matrix{Float64}:
 0.5  1.0  0.0
 1.0  0.5  0.0
 0.0  0.0  0.0
  
julia> myc = LogisticGrowth(foodweb; α = my_α).α
3×3 SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 0.5  1.0   ⋅ 
 1.0  0.5   ⋅ 
  ⋅    ⋅    ⋅   
```

See also [`ModelParameters`](@ref).
"""
function LogisticGrowth(network::EcologicalNetwork; α = nothing, αii = 1.0, αij = 0.0, K = 1) 
    S = richness(network)
    
    # carrying capacity
    isa(K, AbstractVector) || (K = [isproducer(i, network) ? K : nothing for i in 1:S])
    @check_equal_richness length(K) S
    
    # competition
    non_producer = filter(!isproducer, network)
    if isnothing(α)
        # Put the diagonal elements to αii
        α = fill(αij, S, S)
        for i in 1:S
            α[i, i] = αii
        end

        # Put coefficients of non-producers to 0
        α[non_producer, :] .= 0
        α[:, non_producer] .= 0

    else
        # α should be a square matrix
        @assert size(α, 1) == size(α, 2) == S
        # α should be 0 for non producers
        @assert all(α[non_producer, :] .== 0)
        @assert all(α[:, non_producer] .== 0)
    end

    # build
    LogisticGrowth(α, K)
end

"""
NutrientIntake(network, n = 2, D = 0.25, Sₗ = repeat([10.0], n), Cₗ = [range(1, 0.5, length = n);], Kₗᵢ = 1.0)

Creates the parameters needed for the nutrient intake producer growth model, these parameters are: 
    - n the number of nutrient in the model 
    - D the nutrients turnover rate
    - Sₗ the supply concentration for each nutrient
    - Cₗ the relative contents of the nutrients in producers
    - Kₗᵢ the half-saturation densities for nutrient / producer pair

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # species 1 & 2 producers, 3 consumer

julia> def = NutrientIntake(foodweb) # default behavior
NutrientIntake - 2 nutrients:
  D - turnover rate: 0.25
  Sₗ - supply concentrations: [10.0, 10.0]
  Cₗᵢ - relative contents: (2, 2) sparse matrix
  Kₗᵢ - half sat. densities: (2, 2) sparse matrix

julia> def.n
2

julia> def.D
0.25

julia> def.Sₗ
2-element Vector{Float64}:
 10.0
 10.0

julia> def.Cₗᵢ
2×2 SparseMatrixCSC{Float64, Int64} with 4 stored entries:
 1.0  0.5
 1.0  0.5

julia> def.Kₗᵢ
3×2 Matrix{Union{Nothing, Real}}:
 1.0       1.0
 1.0       1.0
  nothing   nothing

julia> # change in the number of producer affects other rates
julia> NutrientIntake(foodweb; n = 4).Kₗᵢ
3×4 Matrix{Union{Nothing, Real}}:
 1.0       1.0       1.0       1.0
 1.0       1.0       1.0       1.0
  nothing   nothing   nothing   nothing

```

See also [`ModelParameters`](@ref).

"""
function NutrientIntake(network::EcologicalNetwork; 
    n = 2,
    D = 0.25,
    Sₗ = repeat([10.0], n),
    Cₗᵢ = [range(1, 0.5, length = n);], 
    Kₗᵢ = 1.0)

    np = length(producers(network))
    S = richness(network)

    # Sanity check turnover (should be in ]0, 1])
    if (D <= 0) || (D > 1)
        throw(ArgumentError("Turnover rate (D) should be in ]0, 1]"))
    end    

    # Check size of supply concentration and convert if needed
    if length(Sₗ) == 1
        Sₗ = repeat([Sₗ], n)
    elseif (length(Sₗ) != n)
        throw(ArgumentError("Sₗ should have length n"))
    end

    # Convert C to array if needed
    sc = size(Cₗᵢ)
    if sc == (np, n)
        Cₗᵢ = sparse(Cₗᵢ)
    elseif sc == (n,)
        C = repeat(Cₗᵢ, np)
        Cₗᵢ = sparse(reshape(C, n, np) |> transpose)
    else
        throw(ArgumentError("Cₗᵢ should be a vector of length n or a matrix with dimensions (number of producer, n)"))
    end

    #Check K and convert if needed
    sk = size(Kₗᵢ)
    if sk == (S, n)
        K = Matrix{Union{Nothing,Float64}}(nothing, S, n)
        K[producers(network), :] = Kₗᵢ[producers(network), :]
        Kₗᵢ = K
    elseif sk == (np, n)
        K = Matrix{Union{Nothing,Float64}}(nothing, S, n)
        K[producers(network), :] = Kₗᵢ
        Kₗᵢ = K
    elseif sk == (np,) || sk == () 
        K = Matrix{Union{Nothing,Float64}}(nothing, S, n)
        K[producers(network), :] .= Kₗᵢ
        Kₗᵢ = K
    else
        throw(ArgumentError("Kₗᵢ should be a Number, a vector of length n or a matrix with dimensions (number of producer, n)"))
    end
    
    NutrientIntake(n, D, Sₗ, Cₗᵢ, Kₗᵢ)

end


#function NutrientIntake
#end
#### end ####

# Producer Growth model functors
"""
    LogisticGrowth(B, i, j)
"""
function (F::LogisticGrowth)(i, B, r, network::MultiplexNetwork, N = nothing)
    r = effect_facilitation(r, i, B, network)
    s = sum(F.α[i, :] .* B) 
    logisticgrowth(B[i], r[i], F.Kᵢ[i], s)
end
function (F::LogisticGrowth)(i, B, r, network::FoodWeb, N = nothing)
    s = sum(F.α[i, :] .* B)
    logisticgrowth(B[i], r[i], F.Kᵢ[i], s)
end
function logisticgrowth(B, r, K, s)
    isnothing(K) && return 0
    r * B * (1 - s / K)
end

"""
    NutrientIntake(B, i, j)
"""
function (F::NutrientIntake)(i, B, r, network::MultiplexNetwork, N)
    r = effect_facilitation(r, i, B, network)
    nutrientintake(B[i], r[i], F.Kₗᵢ[i,:], N)
end
function (F::NutrientIntake)(i, B, r, network::FoodWeb, N)
    nutrientintake(B[i], r[i], F.Kₗᵢ[i,:], N) 
end
function nutrientintake(B, r, K, N)
    all(isnothing.(K)) && return 0
    G_li = N ./ (K .+ N)
    #if N = 0 -> G = NaN, but we want 0 (no growth)
    G_li[isnan.(G_li)] .= 0.0
    minG = minimum(G_li)
    r * B * minG
end
