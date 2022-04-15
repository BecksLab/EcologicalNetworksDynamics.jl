#=
Consumption
=#

function consumption(
    B,
    foodweb::FoodWeb,
    biorates::BioRates,
    F::BioenergeticResponse,
    Environment::Environment
)

    x, y, e = biorates.x, biorates.y, biorates.e
    Fᵢⱼ = F(B)
    eating = x .* y .* B .* Fᵢⱼ
    being_eaten = (eating ./ e) .* foodweb.A

    eating = vec(sum(eating, dims=2)) # sum on prey (i.e. columns)
    being_eaten = vec(sum(being_eaten, dims=1)) # sum on predators (i.e. rows)
    eating, being_eaten
end
