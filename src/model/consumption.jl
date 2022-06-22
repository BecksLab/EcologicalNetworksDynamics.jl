#=
Consumption
=#

"Compute consumption terms of ODEs."
function consumption(i, B, params::ModelParameters{BioenergeticResponse}, fᵣmatrix)
    # Set up
    net = params.network
    prey = preys_of(i, net)
    pred = predators_of(i, net)
    x = params.biorates.x # metabolic rate
    y = params.biorates.y # max. consumption
    e = params.biorates.e # assimilation efficiency

    # Compute consumption terms
    eating = x[i] * y[i] * B[i] * sum(fᵣmatrix[i, prey])
    being_eaten = sum(x[pred] .* y[pred] .* B[pred] .* fᵣmatrix[pred, i] ./ e[pred, i])
    eating, being_eaten
end

function consumption(
    i,
    B,
    params::Union{ModelParameters{ClassicResponse},ModelParameters{LinearResponse}},
    fᵣmatrix
)
    # Set up
    net = params.network
    prey = preys_of(i, net)
    pred = predators_of(i, net)
    e = params.biorates.e

    # Compute consumption terms
    eating = B[i] * sum(e[i, prey] .* fᵣmatrix[i, prey])
    being_eaten = sum(B[pred] .* fᵣmatrix[pred, i])
    eating, being_eaten
end
