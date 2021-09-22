#=
Functional response
=#

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
