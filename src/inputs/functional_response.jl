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
    ; B0::Union{Vector{T}, T}=0.5
    , hill_exponent::T=2.0
    , ω::Union{Nothing, Array{T,2}, SparseMatrixCSC{Float64,Int64}}=nothing
    , interference::Union{T, Vector{Real}}=0.0
    ) where {T <: Real}

    S = richness(FW)
    
    if length(interference) == 1
        interference = repeat([interference], S)
    else
        isequal(S)(length(interference)) || throw(ArgumentError("The interference vector has the wrong number of species"))
    end

    if isnothing(ω)
        ω = homogeneous_preference(FW)
    else
        isequal(S,S)(size(ω)) || throw(ArgumentError("The dimension of the relative preference matrix should be S*S"))
    end

    function classical(B::Vector{Float64}, FW, ω, B0, hill_exponent, interference)
        S = length(FW.species)
        idx = findall(!iszero, FW.A)
        cons = unique([i[1] for i in idx])
        FR = zeros(S,S)

        for c in cons
            idxr = findall(!iszero, FW.A[c,:])
            sumfoodavail = sum(ω[c,:] .* (B .^ hill_exponent))
            for r in idxr
                num = ω[c,r] * (B[r] ^ hill_exponent)
                interf = interference[c] * B[r] * (B0[c] ^ hill_exponent) 
                denom = (B0[c] ^ hill_exponent) + interf + sumfoodavail
                FR[c,r] = num / denom
            end
        end

        FR = sparse(FR)
        return FR
    end

    funcrep = FunctionalResponse(classical, hill_exponent, ω, interference, B0)
    return funcrep
end

function homogeneous_preference(FW::FoodWeb)
    S = length(FW.species)
    ω = zeros(S, S)
    idx = findall(!iszero, FW.A)
    for i in idx
        c = i[1]
        nressource_c = sum(FW.A[c,:])
        ω[i] = 1/nressource_c
    end
    ω = sparse(ω)

    return ω
end
