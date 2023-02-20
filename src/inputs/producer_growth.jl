#=
Models for producer growth
=#

#### Type definition ####
abstract type ProducerGrowth end

struct LogisticGrowth <: ProducerGrowth
    α::SparseMatrixCSC{Float64,Int64} # relative inter to intra-specific competition between producers
    Kᵢ::Vector{Union{Nothing,<:Real}}
end

struct NutrientIntake <: ProducerGrowth
    n::Int64
    D::Real
    Sₗ::Vector{Float64}
    Cₗᵢ::SparseMatrixCSC{Float64}
    Kₗᵢ::Matrix{Union{Nothing,<:Real}}
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
    S = size(model.Cₗᵢ, 1)
    println(io, "NutrientIntake - $(model.n) nutrients:")
    println(io, "  D - turnover rate: $(model.D)")
    println(io, "  Sₗ - supply concentrations: " * vector_to_string(model.Sₗ))
    println(io, "  Cₗᵢ - relative contents: ($S, $S) sparse matrix")
    print(io, "  Kₗᵢ - half sat. densities: ($S, $S) sparse matrix")
end

#### end ####

#### Methods for building ####
"""
    LogisticGrowth(network, α = nothing, αii = 1.0, αij = 0.0, K = 1.0)

Creates the parameters needed for the logistic producer growth model, these parameters are: 
    - α the competition matrix of dimensions S*S, S being the species number of the network. Set to nothing by default.
    - αii the intracompetition term for all species, 1.0 by default.
    - αij the interspecific (relative to intraspecific) competition term for all species, 0.0 by default.
    - Kᵢ the vector of carrying capacities, set to 1 for all producer by default, meaning that each producer gets its own carrying capacity and that the more producer in the system, the larger the overall carrying capacity.

By default, with intraspecific competition set to unity and interspecific competition set to 0, the competition matrix does not affect the system and the model behaves as if where not here. 

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
function LogisticGrowth(network::EcologicalNetwork; α = nothing, αii = 1.0, αij = 0.0, K::Union{Tp,Vector{Union{Nothing,Tp}},Vector{Tp}} = 1) where {Tp<:Real}
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
TODO
"""
function NutrientIntake(network::EcologicalNetwork; 
    n::Int64 = 2,
    D::Real = 0.25,
    Sₗ::Union{Vector{<:Float64},<:Real} = repeat([10.0], n),
    Cₗᵢ::Union{SparseMatrixCSC{<:Float64}, Vector{<:Float64}, Matrix{<:Float64}} = [range(1, 0.5, length = n);], 
    Kₗᵢ::Union{Matrix{Union{Nothing,<:Real}}, <:Real} = 1.0)

    np = length(producers(network))
    S = richness(network)
    # Sanity check turnover (should be in ]0, 1])
    if ((D <= 0) | (D > 1))
        throw(ArgumentError("Turnover rate (D) should be in ]0, 1]"))
    end    

    # Check size of supply concentration and convert if needed
    if (length(Sₗ) == 1)
        Sₗ = repeat([Sₗ], n)
    elseif (length(Sₗ) != n)
        throw(ArgumentError("Sₗ should have length n"))
    end

    # Convert C to array if needed
    if (typeof(Cₗᵢ) == Vector{Float64})
        if (length(Cₗᵢ) != n) 
            throw(ArgumentError("Cₗᵢ should be of length n or dimensions (number of producer, n)"))
        end
        C = repeat(Cₗᵢ, np)
        Cₗᵢ = sparse(reshape(C, n, np) |> transpose)
    elseif (typeof(Cₗᵢ) == Matrix{Float64})
        if (size(Cₗᵢ) != (2,2)) 
            throw(ArgumentError("Cₗᵢ should be of length n or dimensions (number of producer, n)"))
        end
        Cₗᵢ = sparse(Cₗᵢ)
    end

    #Check K and convert if needed
    if (typeof(Kₗᵢ) == Vector{Float64})
        if (length(Kₗᵢ) != n) 
            throw(ArgumentError("Kₗᵢ should be of length n or dimensions (number of producer, n)"))
        end
        C = repeat(Kₗᵢ, np)
        Kₗᵢ = sparse(reshape(C, n, np) |> transpose)
    elseif (typeof(Kₗᵢ) == Matrix{Float64})
        if (size(Kₗᵢ) != (2,2)) 
            throw(ArgumentError("Kₗᵢ should be of length n or dimensions (number of producer, n)"))
        end
        Kₗᵢ = sparse(Kₗᵢ)
    elseif (typeof(Kₗᵢ) <: Real)
        K = Matrix{Union{Nothing,Float64}}(nothing, 3, n)
        K[producers(network), 1:n] .= Kₗᵢ
        Kₗᵢ = K
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
    s = sum(F.α[i, :])
    logisticgrowth(B[i], r[i], F.Kᵢ[i], s)
end
function (F::LogisticGrowth)(i, B, r, network::FoodWeb, N = nothing)
    s = sum(F.α[i, :])
    logisticgrowth(B[i], r[i], F.Kᵢ[i], s)
end
function logisticgrowth(B, r, K, s)
    !isnothing(K) || return 0
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
    !all(isnothing.(K)) || return 0
    G_li = N ./ (K .+ N)
    minG = minimum(G_li)
    r * B * minG
end
