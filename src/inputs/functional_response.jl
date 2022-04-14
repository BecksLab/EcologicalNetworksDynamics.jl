#=
Functional response
=#

"""
    BioEnergeticFunctionalResponse(foodweb; B0, hill_exponent, ω, interference)

Returns an object of type FunctionalResponse where the functional response is the "original"
as originally described by Yodzis and Innes.

- foodweb is a FoodWeb object
- B0 (default is 0.5) is the half saturation density, it can be a single value (same for all consumers) or a vector of size S if you'd like consumer-specific values
- hill_exponent (default is 2 / type III) describes the shape of the functional response (should be between 1 and 2)
- ω (default is homogeneous preference) is a matrix describing cosnumers relative preference for their resources
- interference (default is 0) is teh strength of predator interference in the model
"""
function BioEnergeticFunctionalResponse(
    foodweb::FoodWeb;
    B0::Union{Vector{T},T}=0.5,
    hill_exponent::T=2.0,
    ω::Union{Array{T,2},SparseMatrixCSC{Float64,Int64}}=homogeneous_preference(foodweb),
    interference::Union{T,Vector{Real}}=0.0,
    e_herbivore::T=0.45,
    e_carnivore::T=0.85,
    efficiency=assimilation_efficiency(foodweb, e_herbivore, e_carnivore)
) where {T<:Real}

    S = richness(foodweb)

    # Safety checks
    length(interference) ∈ [1, S] || throw(ArgumentError("\"interference\" wrong length:
        should be of length 1 or S."))
    length(B0) ∈ [1, S] || throw(ArgumentError("B0 wrong length:
        should be of length 1 or S."))
    size(ω) == (S, S) || throw(ArgumentError("ω wrong size: should be of size (S, S), with S
        the species richness."))
    size(efficiency) == (S, S) || throw(ArgumentError("\"efficiency\" wrong size: should be
        of size (S, S), with S the species richness."))

    # Format input
    length(interference) == S || (interference = repeat([interference], S))
    length(B0) == S || (B0 = repeat([B0], S))
    efficiency = sparse(efficiency)

    FunctionalResponse(bioenergetic, hill_exponent, ω, interference, B0, efficiency)
end

function bioenergetic(B, foodweb, ω, B₀, h, cᵢ)

    # Set up
    S = richness(foodweb)
    consumer, resource = findnz(foodweb.A)
    n_interactions = length(consumer) # number of trophic interactions
    F = zeros(S, S)

    # Fill functional response matrix
    for n in 1:n_interactions
        i, j = consumer[n], resource[n]
        numerator = ω[i, j] * B[j]^h
        denominator = (B₀[i]^h) + (cᵢ[i] * B[i] * B₀[i]^h) + (sum(ω[i, :] .* (B .^ h)))
        F[i, j] = numerator / denominator
    end

    sparse(F)
end

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

function assimilation_efficiency(foodweb::FoodWeb, e_herbivore, e_carnivore)

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
    S = richness(foodweb)
    length(c) == S || (c = repeat([c], S))
    ClassicResponse(Float64(h), Float64.(ω), Float64.(c), Float64(hₜ), Float64(aᵣ))
end
