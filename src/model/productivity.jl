#=
Productivity
=#

function logisticgrowth(B, foodweb::FoodWeb, biorates::BioRates, Environment::Environment)

    # Set up
    r = biorates.r # intrinsic growth rate
    K = Environment.K # carrying capacity

    # Compute logistic growth for all species
    logisticgrowth.(B, r, K)
end

function logisticgrowth(B, r, K)
    !isnothing(K) || return 0 # if carrying capacity is null, growth is null too (avoid NaNs)
    r * B * (1 - B / K)
end
