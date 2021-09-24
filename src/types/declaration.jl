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
        isequal(size(A,1))(size(A,2)) || throw(ArgumentError("The adjacency matrix should be square"))
        isless(S, length(species)) && throw(ArgumentError("That's too many species... there is more species defined than specified in the adjacency matrix"))
        length(species)<S && throw(ArgumentError("That's too few species... there is less species defined than specified in the adjacency matrix"))
        _cleanmetabolicclass!(metabolic_class, A)
        new(A, species, M, metabolic_class, method) 
    end
end

"""
Functional response
"""

mutable struct FunctionalResponse
    functional_response::Function
    hill_exponent::Real
    ω::SparseMatrixCSC{Float64,Int64}
    c::Vector{T} where {T <: Real}
    B0::Union{T, Vector{T}} where {T <: Real}
    e::SparseMatrixCSC{Float64,Int64}
    function FunctionalResponse(functional_response, hill_exponent, ω, c, B0, e) 
        new(functional_response, hill_exponent, ω, c,  B0, e)
    end
end

"""
Biological Rates
"""

mutable struct BioRates
    r::Vector{<:Real}
    x::Vector{<:Real}
    y::Vector{<:Real}
    function BioRates(r,x,y) 
        new(r,x,y)
    end
end

"""
Environmental variables
"""

mutable struct Environment
    K::Vector{<:Real}
    T::Union{Int64, Float64}
    function Environment(K,T)
        new(K,T)
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
