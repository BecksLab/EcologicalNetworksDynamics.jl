#=
Productivity
=#

function logisticgrowth(i, B, rᵢ, Kᵢ, network::FoodWeb)
    logisticgrowth(B[i], rᵢ, Kᵢ)
end

function logisticgrowth(i, B, rᵢ, Kᵢ, network::MultiplexNetwork)
    rᵢ = r_facilitated(rᵢ, i, B, network)
    logisticgrowth(B[i], rᵢ, Kᵢ)
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
    A_facilitation = network.facilitation_layer.A
    facilitating_species = A_facilitation[:, i]
    f0 = network.facilitation_layer.intensity
    r * (1 + f0 * sum(B .* facilitating_species))
end
