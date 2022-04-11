#=
Functional response
=#

"""
    originalFW(FW; B0, hill_exponent, ω, interference)

Returns an object of type FunctionalResponse where the functional response is the "original"
as originally described by Yodzis and Innes.

- FW is a FoodWeb object
- B0 (default is 0.5) is the half saturation density, it can be a single value (same for all consumers) or a vector of size S if you'd like consumer-specific values
- hill_exponent (default is 2 / type III) describes the shape of the functional response (should be between 1 and 2)
- ω (default is homogeneous preference) is a matrix describing cosnumers relative preference for their resources
- interference (default is 0) is teh strength of predator interference in the model
"""
function originalFR(FW::FoodWeb,
    ; B0::Union{Vector{T},T}=0.5,
    hill_exponent::T=2.0,
    ω::Union{Nothing,Array{T,2},SparseMatrixCSC{Float64,Int64}}=nothing,
    interference::Union{T,Vector{Real}}=0.0,
    efficiency=nothing,
    e_herbivore::T=0.45,
    e_carnivore::T=0.85
) where {T<:Real}

    S = richness(FW)

    if length(interference) == 1
        interference = repeat([interference], S)
    else
        isequal(S)(length(interference)) || throw(ArgumentError("The interference vector has the wrong number of species"))
    end

    if isnothing(ω)
        ω = homogeneous_preference(FW)
    else
        isequal(S, S)(size(ω)) || throw(ArgumentError("The dimension of the relative preference matrix should be richness(FoodWeb)*richness(FoodWeb)"))
    end

    if isnothing(efficiency)
        efficiency = assimilation_efficiency(FW, e_herbivore, e_carnivore)
    else
        if length(efficiency) == 1
            efficiency = FW.A .* efficiency
        else
            isequal(S, S)(size(efficiency)) || throw(ArgumentError("The dimension of the assimilation efficiency matrix should be richness(FoodWeb)*richness(FoodWeb). Alternatively, you can provide a single value, or specify the e_herbivore and e_carnivore arguments."))
            efficiency = sparse(efficiency)
        end
    end

    if length(B0) == 1
        B0 = repeat([B0], S)
    else
        isequal(S)(length(B0)) || throw(ArgumentError("The length of the half saturation vector should be richness(FoodWeb). Alternatively, you can provide a single value."))
    end

    function bioenergetic(B::Vector{Float64}, FW, ω, B0, hill_exponent, interference)
        S = length(FW.species)
        idx = findall(!iszero, FW.A)
        cons = unique([i[1] for i in idx])
        FR = zeros(S, S)

        for c in cons
            idxr = findall(!iszero, FW.A[c, :])
            sumfoodavail = sum(ω[c, :] .* (B .^ hill_exponent))
            for r in idxr
                num = ω[c, r] * (B[r]^hill_exponent)
                interf = interference[c] * B[r] * (B0[c]^hill_exponent)
                denom = (B0[c]^hill_exponent) + interf + sumfoodavail
                FR[c, r] = num / denom
            end
        end

        FR = sparse(FR)
        return FR
    end

    funcrep = FunctionalResponse(bioenergetic, hill_exponent, ω, interference, B0, efficiency)
    return funcrep
end

function homogeneous_preference(FW::FoodWeb)
    S = length(FW.species)
    ω = zeros(S, S)
    idx = findall(!iszero, FW.A)
    for i in idx
        c = i[1]
        nressource_c = sum(FW.A[c, :])
        ω[i] = 1 / nressource_c
    end
    ω = sparse(ω)

    return ω
end

function assimilation_efficiency(FW::FoodWeb, e_herbivore, e_carnivore)
    S = richness(FW)
    efficiency = zeros(Float64, (S, S))
    idp = whoisproducer(FW.A)
    for consumer in 1:S
        for resource in 1:S
            if FW.A[consumer, resource]
                if idp[resource]
                    efficiency[consumer, resource] = e_herbivore
                else
                    efficiency[consumer, resource] = e_carnivore
                end
            end
        end
    end
    return sparse(efficiency)
end
