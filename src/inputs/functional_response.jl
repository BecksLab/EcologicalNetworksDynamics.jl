#=
Functional response
=#

#### Type definition ####
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
#### end ####

#### Type display ####
function Base.show(io::IO, F::ClassicResponse)
    println(io, "Classic functional response")
    print(io, "hill exponent = $(F.h)")
end

function Base.show(io::IO, F::BioenergeticResponse)
    println(io, "Bioenergetic functional response")
    print(io, "hill exponent = $(F.h)")
end
#### end ####

"""
    homogeneous_preference(foodweb)

Create the preferency matrix (`ω`) which describes how each predator split its time
between its different preys.
`ω[i,j]` is the fraction of time of predator i spent on prey j.
By definition, ∀i ``\\sum_j \\omega_{ij} = 1``.
Here we assume an **homogeneous** preference, meaning that each predator split its time
equally between its preys, i.e. ∀j ``\\omega_{ij} = \\omega_{i} = \\frac{1}{n_{preys,i}}``
where ``n_{preys,i}`` is the number of prey of predator i.
"""
function homogeneous_preference(foodweb::FoodWeb)

    # Set up
    S = richness(foodweb)
    ω = spzeros(S, S)
    consumer, resource = findnz(foodweb.A)
    num_resources = resourcenumber(consumer, foodweb) # Dict: consumer => number resources
    n_interactions = length(consumer) # number of interactions

    # Fill preference matrix
    for n in 1:n_interactions
        i, j = consumer[n], resource[n]
        ω[i, j] = 1 / num_resources[i]
    end

    ω
end

"""
    assimilation_efficiency(foodweb; e_herbivore=0.45, e_carnivore=0.85)

Create the assimilation efficiency matrix (`Efficiency`).
`Efficiency[i,j]` is the assimation efficiency of predator i eating prey j.
A perfect efficiency corresponds to an efficiency of 1.
The efficiency depends on the metabolic class of the prey:
- if prey is producter, efficiency is `e_herbivore`
- otherwise efficiency is `e_carnivore`

Default values are taken from *add ref*.
"""
function assimilation_efficiency(foodweb::FoodWeb; e_herbivore=0.45, e_carnivore=0.85)

    # Set up
    S = richness(foodweb)
    efficiency = spzeros(Float64, (S, S))
    isproducer = whoisproducer(foodweb.A)
    consumer, resource = findnz(foodweb.A) # indexes of trophic interactions
    n_interactions = length(consumer) # number of trophic interactions

    # Fill efficiency matrix
    for n in 1:n_interactions
        i, j = consumer[n], resource[n]
        efficiency[i, j] = isproducer[j] ? e_herbivore : e_carnivore
    end

    efficiency
end

# Functional response functors
"""
    BioenergeticResponse(B, i, j)

Compute the bionergetic functional response for predator `i` eating prey `j`, given the
species biomass `B`.
The bionergetic functional response is written:
```math
F_{ij} = \\frac{\\omega_{ij} B_j^h}{B_0^h + c_i B_i B_0^h + \\sum_k \\omega_{ik} B_k^h}
```
With:
- ``\\omega`` the preferency, by default we assume that predators split their time equally
    among their preys, i.e. ∀j ``\\omega_{ij} = \\omega_{i} = \\frac{1}{n_{i,preys}}``
    where ``n_{i,preys}`` is the number of preys of predator i.
- ``h`` the hill exponent, if ``h = 1`` the functional response is of type II, and of type
    III if ``h = 2``
- ``c_i`` the intensity of predator intraspecific inteference
- ``B_0`` the half-saturation density.

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> F = BioenergeticResponse(foodweb)
Bioenergetic functional response
hill exponent = 2.0

julia> F([1, 1], 1, 2) # no interaction, 1 does not eat 2
0.0

julia> F([1, 1], 2, 1) # interaction, 2 eats 1
0.8

julia> F([1.5, 1], 2, 1) # increases with resource biomass
0.9
```

See also [`ClassicResponse`](@ref) and [`FunctionalResponse`](@ref).
"""
function (F::BioenergeticResponse)(B, i, j)
    num = F.ω[i, j] * B[j]^F.h
    denom = (F.B0[i]^F.h) + (F.c[i] * B[i] * F.B0[i]^F.h) + (sum(F.ω[i, :] .* (B .^ F.h)))
    num / denom
end

"""
    ClassicResponse(B, i, j)

Compute the classic functional response for predator `i` eating prey `j`, given the
species biomass `B`.
The classic functional response is written:
```math
F_{ij} = \\frac{\\omega_{ij} a_{r,ij} B_j^h}{1 + c_i B_i + h_t \\sum_k \\omega_{ik} a_{r,ik} B_k^h}
```
With:
- ``\\omega`` the preferency, by default we assume that predators split their time equally
    among their preys, i.e. ∀j ``\\omega_{ij} = \\omega_{i} = \\frac{1}{n_{i,preys}}``
    where ``n_{i,preys}`` is the number of preys of predator i.
- ``h`` the hill exponent, if ``h = 1`` the functional response is of type II, and of type
    III if ``h = 2``
- ``c_i`` the intensity of predator intraspecific inteference
- ``a_{r,ij}`` the attack rate of predator i on prey j
- ``h_t`` the handling time of predators.

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> F = ClassicResponse(foodweb)
Classic functional response
hill exponent = 2.0

julia> F([1, 1], 1, 2) # no interaction, 1 does not eat 2
0.0

julia> round(F([1, 1], 2, 1), digits = 2) # interaction, 2 eats 1
0.33

julia> round(F([1.5, 1], 2, 1), digits = 2) # increases with resource biomass
0.53
```

See also [`BioenergeticResponse`](@ref) and [`FunctionalResponse`](@ref).
"""
function (F::ClassicResponse)(B, i, j)
    num = F.ω[i, j] * F.aᵣ[i, j] * B[j]^F.h
    denom = 1 + (F.c[i] * B[i]) + sum(F.aᵣ[i, :] .* F.hₜ[i, :] .* F.ω[i, :] .* (B .^ F.h))
    num / denom
end

"""
    FunctionalResponse(B)

Compute functional response matrix given the species biomass `B`.
If `B` is a scalar, all species are assumed to have the same biomass `B`.
Otherwise provide a vector s.t. `B[i]` = biomass of species i.

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> F = BioenergeticResponse(foodweb)
Bioenergetic functional response
hill exponent = 2.0

julia> F([1, 1]) # providing a species biomass vector
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅    ⋅
 0.8   ⋅

julia> F(1) # or a scalar if homogeneous
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅    ⋅
 0.8   ⋅

julia> F([1.5, 1]) # response increases with resource biomass
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅    ⋅
 0.9   ⋅
```

See also [`BioenergeticResponse`](@ref) and [`ClassicResponse`](@ref).
"""
function (F::FunctionalResponse)(B)

    # Safety checks and format
    S = size(F.ω, 1) #! Care: your functional response should have a parameter ω
    length(B) ∈ [1, S] || throw(ArgumentError("B wrong length: should be of length 1 or S
        (species richness)."))
    length(B) == S || (B = repeat([B], S))

    # Set up
    consumer, resource = findnz(F.ω)
    n_interactions = length(consumer) # number of trophic interactions
    F_matrix = spzeros(S, S)

    # Fill functional response matrix
    for n in 1:n_interactions
        i, j = consumer[n], resource[n]
        F_matrix[i, j] = F(B, i, j)
    end

    sparse(F_matrix)
end

# Methods to build Classic and Bionergetic structs
function BioenergeticResponse(
    foodweb::FoodWeb;
    B0=0.5,
    h=2.0,
    ω=homogeneous_preference(foodweb),
    c=0.0
)
    S = richness(foodweb)
    length(c) == S || (c = repeat([c], S))
    length(B0) == S || (B0 = repeat([B0], S))
    BioenergeticResponse(Float64(h), Float64.(ω), Float64.(c), Float64.(B0))
end

function ClassicResponse(
    foodweb::FoodWeb;
    aᵣ=0.5,
    hₜ=1.0,
    h=2.0,
    ω=homogeneous_preference(foodweb),
    c=0.0
)

    # Safety checks
    S = richness(foodweb)
    size(hₜ) ∈ [(), (S, S)] || throw(ArgumentError("hₜ wrong size: should be a scalar or a
        of size (S, S) with S the species richness."))
    size(aᵣ) ∈ [(), (S, S)] || throw(ArgumentError("aᵣ wrong size: should be a scalar or a
        of size (S, S) with S the species richness."))
    length(c) ∈ [1, S] || throw(ArgumentError("c wrong length: should be of length 1 or S
        (species richness)."))
    size(ω) == (S, S) || throw(ArgumentError("ω wrong size: should be of size (S, S)
        with S the species richness."))

    # Format
    size(hₜ) == (S, S) || (hₜ = scalar_to_sparsematrix(hₜ, foodweb.A))
    size(aᵣ) == (S, S) || (aᵣ = scalar_to_sparsematrix(aᵣ, foodweb.A))
    aᵣ = sparse(aᵣ)
    hₜ = sparse(hₜ)
    length(c) == S || (c = repeat([c], S))

    ClassicResponse(Float64(h), Float64.(ω), Float64.(c), Float64.(hₜ), Float64.(aᵣ))
end
