"""
    Community
"""

"""
    A FoodWeb is a collection of the following fields:

- `A` is the (sparse) interaction matrix of boolean values
- `species` is a vector of species identities
- `M` is a vector of species body mass
- `metabolic_class` is a vector of species metabolic classes
- `method` is a String describing the model (if any) used to generate the food web, but can also contain whatever String users want to input (food web source, etc...)
"""
mutable struct FoodWeb
    A::SparseMatrixCSC{Bool,Int64}
    species::Vector{String}
    M::Vector{Real}
    metabolic_class::Vector{String}
    method::String
    function FoodWeb(A, species, M, metabolic_class, method)
        S = size(A, 1)
        isequal(size(A, 1))(size(A, 2)) || throw(ArgumentError("The adjacency matrix should be square"))
        isless(S, length(species)) && throw(ArgumentError("That's too many species... there is more species defined than specified in the adjacency matrix"))
        length(species) < S && throw(ArgumentError("That's too few species... there is less species defined than specified in the adjacency matrix"))
        _cleanmetabolicclass!(metabolic_class, A)
        new(A, species, M, metabolic_class, method)
    end
end

"""
Functional response
"""

abstract type FunctionalResponse end
#! Children of abstract type FunctionalResponse are all expected to have a .ω member.
#! Otherwise homogeneous_preference will fail.

struct BioenergeticResponse <: FunctionalResponse
    h::Float64 # hill exponent
    ω::SparseMatrixCSC{Float64} # ressource preferency
    c::Vector{Float64} # intraspecific interference
    B0::Vector{Float64} # half-saturation
end

struct ClassicResponse <: FunctionalResponse
    h::Float64 # hill exponent
    ω::SparseMatrixCSC{Float64} # ressource preferency
    c::Vector{Float64} # intraspecific interference
    hₜ::SparseMatrixCSC{Float64} # handling time
    aᵣ::SparseMatrixCSC{Float64} # attack rate
end

"""
Biological Rates
"""
mutable struct BioRates
    r::Vector{<:Real}
    x::Vector{<:Real}
    y::Vector{<:Real}
    function BioRates(r, x, y)
        new(r, x, y)
    end
end

"""
Environmental variables
"""
mutable struct Environment
    K::Vector{<:Real}
    T::Union{Int64,Float64}
    function Environment(K, T)
        new(K, T)
    end
end

"""
    Model parameters
"""
mutable struct ModelParameters
    FoodWeb::FoodWeb
    BioRates::BioRates
    Environment::Environment
    FunctionalResponse::FunctionalResponse
end

"""
    Outputs
"""
