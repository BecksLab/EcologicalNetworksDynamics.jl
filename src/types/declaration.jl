"""
    Community
"""

abstract type AbstractFoodWeb end

"""
    A FoodWeb is a collection of the following fields: 

- `A` is the (sparse) interaction matrix of boolean values
- `species` is a vector of species identities
- `M` is a vector of species body mass
- `metabolic_class` is a vector of species metabolic classes
- `method` is a String describing the model (if any) used to generate the food web, but can also contain whatever String users want to input (food web source, etc...)
"""
mutable struct FoodWeb <: AbstractFoodWeb
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
    Model parameters 
"""
abstract type AbstractParameters end

mutable struct BEFWMParameters <: AbstractParameters
    A::SparseMatrixCSC{Bool,Int64}
    species::Vector{String}
    M::Vector{Real}
    metabolic_class::Vector{String}
    method::String
    r::Vector{Real}
    x::Vector{Real}
    y::Vector{Real}
    B0::Vector{Real}
    hill_exponent::Real
    functional_response::Function
    scale_mass::Bool
    scale_biologicalrates::Bool
    function BEFWMParameters(A, species, M, metabolic_class, method, r, x, y, B0, hill_exponent, functional_response, scale_mass, scale_biologicalrates) 
        S = size(A, 1)
        isequal(S)(length(r)) || throw(ArgumentError("The vector of species growth rates (r) should have the same length as there are species in the food web"))
        isequal(S)(length(x)) || throw(ArgumentError("The vector of species metabolic rates (x) should have the same length as there are species in the food web"))
        isequal(S)(length(y)) || throw(ArgumentError("The vector of species max. consumption rates (y) should have the same length as there are species in the food web"))
        isequal(S)(length(B0)) || throw(ArgumentError("The vector of species half saturation densities (B0) should have the same length as there are species in the food web"))
        new(A, species, M, metabolic_class, method, r, x, y, B0, hill_exponent, functional_response, scale_mass, scale_biologicalrates)
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
    function FunctionalResponse(functional_response, hill_exponent, ω, c, B0) 
        new(functional_response, hill_exponent, ω, c,  B0)
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
    Outputs
"""
abstract type AbstractOutputs end