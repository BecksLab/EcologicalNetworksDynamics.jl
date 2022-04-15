#=
Functional response
=#

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
"Bionergetic functional response for predator i eating prey j, given the species biomass B."
function (F::BioenergeticResponse)(B, i, j)
    num = F.ω[i, j] * B[j]^F.h
    denom = (F.B0[i]^F.h) + (F.c[i] * B[i] * F.B0[i]^F.h) + (sum(F.ω[i, :] .* (B .^ F.h)))
    num / denom
end

"Classic functional response for predator i eating prey j, given the species biomass B."
function (F::ClassicResponse)(B, i, j)
    num = F.ω[i, j] * F.aᵣ[i, j] * B[j]^F.h
    denom = 1 + (F.c[i] * B[i]) + sum(F.aᵣ[i, :] .* F.hₜ[i, :] .* F.ω[i, :] .* (B .^ F.h))
    num / denom
end

"Compute functional response matrix given the species biomass (B)."
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
