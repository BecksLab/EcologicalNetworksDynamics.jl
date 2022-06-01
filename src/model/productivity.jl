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

"""
Intrinsic growth rate of species i increased by facilitation.
The new intrinsic growth rate `r_facilitated` is given by:
``r'  = r (1 + f_0 \\sum_{k \\in \\{\\text{fac.}\\} B_k``
"""
function r_facilitated(r, i, B, network::MultiplexNetwork)
    facilitating_species = network.facilitation[:, i]
    f0 = network.nontrophic_intensity.f0
    r * (1 + f0 * sum(B .* facilitating_species))
end
