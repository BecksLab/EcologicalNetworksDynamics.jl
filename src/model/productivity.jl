#=
Productivity
=#

function logisticgrowth(i, B, params::ModelParameters)
    rᵢ = params.biorates.r[i] # intrinsic growth rate of species i
    Kᵢ = params.environment.K[i] # carrying capacity of species i
    Bᵢ = B[i] # biomass of species i
    logisticgrowth(Bᵢ, rᵢ, Kᵢ)
end

function logisticgrowth(B, r, K)
    !isnothing(K) || return 0 # if carrying capacity is null, growth is null too (avoid NaNs)
    r * B * (1 - B / K)
end
