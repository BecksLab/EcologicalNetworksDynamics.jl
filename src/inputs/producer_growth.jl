#=
Models for producer growth
=#

#### Type definition ####
abstract type ProducerGrowth end

struct LogisticGrowth <: ProducerGrowth
    α::SparseMatrixCSC{Float64,Int64} # relative inter to intra-specific competition between producers
    Kᵢ::Vector{Float64}
end

struct NutrientIntake <: ProducerGrowth
    n::Int64
    D::Real
    Sₗ::Vector{Float64}
    Cₗᵢ::SparseMatrixCSC{Float64}
    Kₗᵢ::Matrix{Float64}
end
#### end ####

#### Type display ####
#TODO
#### end ####

# Producer Growth model functors
"""
    LogisticGrowth(B, i, j)
"""
function (F::LogisticGrowth)(i, B, N, r, s, network::MultiplexNetwork)
    r = effect_facilitation(r, i, B, network)
    logisticgrowth(B[i], r, F.K, s)
end
function (F::LogisticGrowth)(i, B, N, r, s, network::FoodWeb)
    logisticgrowth(B, r, F.K, s)
end
function logisticgrowth(B, r, K, s = B, N = 0)
    !isnothing(K) || return 0
    r * B * (1 - s / K)
end

"""
    NutrientIntake(B, i, j)
"""
function (F::NutrientIntake)(i, B, N, r, s, network::MultiplexNetwork)
    r = effect_facilitation(r, i, B, network)
    nutrientintake(B[i], N, r, F.K, s)
end
function (F::NutrientIntake)(i, B, N, r, s, network::FoodWeb)
    nutrientintake(B[i], N, r, F.K, s) 
end
function nutrientintake(B, N, r, K, s = B)
    
end