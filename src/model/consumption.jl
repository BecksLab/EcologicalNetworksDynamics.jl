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

function consumption(
    B,
    foodweb::FoodWeb,
    biorates::BioRates,
    F::ClassicResponse,
    Environment::Environment
)

    e = biorates.e
    Fᵢⱼ = F(B)
    being_eaten = B .* Fᵢⱼ
    eating = e .* being_eaten

    eating = vec(sum(eating, dims=2)) # sum on prey (i.e. columns)
    being_eaten = vec(sum(being_eaten, dims=1)) # sum on predators (i.e. rows)
    eating, being_eaten
end

function consumption(i, B, params::ModelParameters{BioenergeticResponse}, fᵣmatrix)

    # Set up
    foodweb = params.FoodWeb
    res = resource(i, foodweb) # ressource of species i
    cons = consumer(i, foodweb) # consumer of species i
    x = params.BioRates.x # metabolic rate
    y = params.BioRates.y # max. consumption
    e = params.BioRates.e # assimilation efficiency

    # Compute consumption terms
    eating = x[i] * y[i] * B[i] * sum(fᵣmatrix[i, res])
    being_eaten = sum(x[cons] .* y[cons] .* B[cons] .* fᵣmatrix[cons, i] ./ e[cons, i])

    eating, being_eaten
end

function consumption(i, B, params::ModelParameters{ClassicResponse}, fᵣmatrix)

    # Set up
    foodweb = params.FoodWeb
    res = resource(i, foodweb) # ressource of species i
    cons = consumer(i, foodweb) # consumer of species i
    e = params.BioRates.e # assimilation efficiency

    # Compute consumption terms
    eating = B[i] * sum(e[i, res] .* fᵣmatrix[i, res])
    being_eaten = sum(B[cons] .* fᵣmatrix[cons, i])

    eating, being_eaten
end
