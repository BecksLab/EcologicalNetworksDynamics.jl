#=
Productivity
=#

function logisticgrowth(B, foodweb::FoodWeb, biorates::BioRates, Environment::Environment)

    # Set up
    isproducer = whoisproducer(foodweb)
    r = biorates.r # intrinsic growth rate
    K = Environment.K # carrying capacity

    # Compute logistic growth
    growth = r .* B .* (1 .- (B ./ K))
    growth .* isproducer # non-producer have null growth
end
