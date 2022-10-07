#### Functors for temperature dependence methods ####

# No Temperature Response Functor
function (F::NoTemperatureResponse)(params::ModelParameters, T)
    # record temperature in env, even though it has no effect
    params.environment.T = T
end

# Exponential Boltzmann Arrhenius Functor.
function (F::ExponentialBA)(params::ModelParameters, T;)
    net = params.network
    tp = ExponentialBA()
    ## change params within BioRates
    params.biorates.r = Vector{Float64}(exp_ba_vector_rate(net, T, tp.r))
    params.biorates.x = Vector{Float64}(exp_ba_vector_rate(net, T, tp.x))
    ## change params within FunctionalResponse
    params.functional_response.hₜ = exp_ba_matrix_rate(net, T, tp.hₜ)
    params.functional_response.aᵣ = exp_ba_matrix_rate(net, T, tp.aᵣ)
    ## change params within Environment
    params.environment.K = exp_ba_vector_rate(net, T, tp.K)
    params.environment.T = T
end

### setting the temperature 

# The entry point for the user.
function set_temperature!(p::ModelParameters, T, F!::TemperatureResponse)

    # error - can only be used with bioenergetic functional response
    if isa(F!, ExponentialBA) & !(isa(p.functional_response, ClassicResponse))
        type_response = typeof(p.functional_response)
        throw(ArgumentError("Temperature dependence isn't implented for '$type_response'.
            Use a functional response of type 'ClassicResponse' instead."))
    end

    # Apply the functor to the parameters.
    F!(p, T)
    # Record which functor has been used for these parameters.
    p.temperature_response = F!
    p

end
