#### Functors for temperature dependence methods ####

# No Temperature Response Functor
function (F::NoTemperatureResponse)(params::ModelParameters, T)
    # record temperature in env, even though it has no effect
    params.environment.T = T
end

# Exponential Boltzmann Arrhenius Functor.
function (F::ExponentialBA)(params::ModelParameters, T)
    net = params.network
    tp = ExponentialBA()
    ## change params within BioRates
    params.biorates.r = exponentialBA_vector_rate(net, T, tp.defaults_r)
    params.biorates.x = exponentialBA_vector_rate(net, T, tp.defaults_x)
    ## change params within FunctionalResponse
    params.functional_response.hₜ = exponentialBA_matrix_rate(net, T, tp.defaults_hₜ)
    params.functional_response.aᵣ = exponentialBA_matrix_rate(net, T, tp.defaults_aᵣ)
    ## change params within Environment
    params.environment.K = exponentialBA_vector_rate(net, T, tp.defaults_K)
    params.environment.T = T
end

### setting the temperature 

# The entry point for the user.
function set_temperature!(p::ModelParameters, T, F!::TemperatureResponse)
    # Apply the functor to the parameters.
    F!(p, T)
    # Record which functor has been used for these parameters.
    p.temperature_response = F!
    p
end
