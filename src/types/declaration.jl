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

"""
    Outputs
"""
abstract type AbstractOutputs end