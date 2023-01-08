#=
NUTRIENT INTAKE
=#

#### Type definition ####
"""
    NIntakeParams(n, Dₗ, Sₗ, Cₗ)

Parameters used to compute the nutrient intake model.

The nutrient intake model, as described in Brose et al., 2008 
(doi:10.1098/rspb.2008.0718), models nutrient concentrations through time 
and how they affect producers growth as follow (example with two nutrients N₁
and N₂): 

``Gᵢ(N) = MIN(N₁ / (K₁ᵢ + N₁) , N₂ / (K₂ᵢ + N₂))``

where

``Nₗ(t) = D(Sₗ - Nₗ) - ∑ⁿ(cₗᵢ rᵢ Gᵢ(N) Bᵢ)`` 

The parameters of this model are stored in this `NIntakeParams` struct:
    - `n`: number of nutrients (default is 2)
    - `D`: turnover rate at which nutrients are exchanged (relative to the growth rate of the producer)
    - `Sₗ`: supply concentration for each nutrient
    - `Cₗᵢ`: relative content of each nutrient in producer's i biomass

# Example
```jldoctest
#TODO
```
"""
struct NIntakeParams
    n::Int64
    D::Real
    Sₗ::Vector{Float64}
    Cₗᵢ::SparseMatrixCSC{Float64}
end
#### end ####

#### Type display ####
function Base.show(io::IO, nparams::NIntakeParams)
    n, D = nparams.n, nparams.D
    Sₗ, Cₗᵢ = nparams.Sₗ, nparams.Cₗᵢ
    println(io, " Nutrient intake model parameters:")
    println(io, " Number of nutrients - n: " * vector_to_string(n))
    println(io, " Turnover rate - D: " * vector_to_string(D))
    println(io, " Supply concentration - Sₗ: " * vector_to_string(Sₗ))
    println(io, " Relative content in producers - Cₗᵢ: " * vector_to_string(Cₗᵢ))
end
#### end ####

#### Constructors containing default parameter value for the nutrient intake model parameters ####
"""
    DefaultNIntakeParams()

Default nutrient intake model parameters values.

See also [`NIntakeParams`](@ref)
"""
DefaultNIntakeParams() = NIntakeParams(2, 0.25, [10, 10], sparse([1 0.5 ; 1 0.5]))

#### Main functions to compute parameters for the nutrient intake model ####
"""
    NutrientIntake(n, D, Sₗ Cₗᵢ)

# Examples

```jldoctest
julia> 
```
"""

function NIntakeParams(
    network::EcologicalNetwork;
    n::Int64 = 2,
    D::Real = 0.25,
    Sₗ::Union{Vector{<:Float64},<:Real} = repeat([10.0], n),
    Cₗᵢ::Union{SparseMatrixCSC{<:Float64}, Vector{<:Float64}, Matrix{<:Float64}} = [range(1, 0.5, length = n);],
    )

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
        np = length(producers(network))
        C = repeat(Cₗᵢ, np)
        Cₗᵢ = sparse(reshape(C, n, np) |> transpose)
    elseif (typeof(Cₗᵢ) == Matrix{Float64})
        if (size(Cₗᵢ) != (2,2)) 
            throw(ArgumentError("Cₗᵢ should be of length n or dimensions (number of producer, n)"))
        end
        Cₗᵢ = sparse(Cₗᵢ)
    end

    # Output
    NIntakeParams(n, D, Sₗ, Cₗᵢ)
end
