#=
Consumption
=#

"Compute consumption terms of ODEs."
function consumption(i, B, p::ModelParameters, fᵣmatrix)
    # Dispatch to correct method depending on functional response type.
    consumption(p.functional_response, i, B, p::ModelParameters, fᵣmatrix)
end

function consumption(::BioenergeticResponse, i, B, params::ModelParameters, fᵣmatrix)
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
# Code generation version(s) (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
eating(i, p::ModelParameters) = eating(p.functional_response, i, p) # (dispatch)
function eating(::BioenergeticResponse, i, parms::ModelParameters)
    preys = preys_of(i, parms.network)
    B_i = :(B[$i])
    x_i = parms.biorates.x[i]
    y_i = parms.biorates.y[i]
    F_ip = [Symbol("F_$(i)_$(p)") for p in preys]
    (x_i == 0 || y_i == 0 || length(preys) == 0) && return 0 #  Just to clarify expressions.
    :($x_i * $y_i * $B_i * xp_sum([:f_ip], $[F_ip], :(f_ip)))
end
being_eaten(i, p::ModelParameters) = being_eaten(p.functional_response, i, p) # (dispatch)
function being_eaten(::BioenergeticResponse, i, parms::ModelParameters)
    preds = predators_of(i, parms.network)
    x = parms.biorates.x[preds]
    y = parms.biorates.y[preds]
    e_pi = [parms.biorates.e[p, i] for p in preds]
    F_pi = [Symbol("F_$(p)_$(i)") for p in preds]
    :(xp_sum(
        [:p, :xp, :yp, :e_pi, :f_pi],
        $[preds, x, y, e_pi, F_pi],
        :(xp * yp * B[p] * f_pi / e_pi),
    ))
end

function consumption(
    ::Union{ClassicResponse,LinearResponse},
    i,
    B,
    params::ModelParameters,
    fᵣmatrix,
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
