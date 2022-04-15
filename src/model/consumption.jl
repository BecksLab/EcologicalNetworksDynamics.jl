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

    x, y, e = biorates.x, biorates.y, F.Efficiency
    Fᵢⱼ = F(B)
    eating = x .* y .* B .* Fᵢⱼ
    being_eaten = (eating ./ e) .* foodweb.A

    eating = vec(sum(eating, dims=2))
    being_eaten = vec(sum(being_eaten, dims=1))
    eating, being_eaten
end
