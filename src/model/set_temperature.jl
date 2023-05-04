#### Functors for temperature dependence methods ####

# Record temperature in Environment even though it has no effect.
(F::NoTemperatureResponse)(params::ModelParameters, T) = params.environment.T = T

# Exponential Boltzmann Arrhenius Functor.
function (F::ExponentialBA)(params::ModelParameters, T;)
    isa(params.producer_growth, NutrientIntake) && throw(
        ArgumentError(
            "Temperature dependence is not compatible with nutrient intake dynamics. \
            Either deactivate temperature dependence or \
            switch producer growth to `$LogisticGrowth`.",
        ),
    )
    net = params.network
    params.biorates.r = Vector{Float64}(exp_ba_vector_rate(net, T, F.r))
    params.biorates.x = Vector{Float64}(exp_ba_vector_rate(net, T, F.x))
    params.functional_response.hₜ = exp_ba_matrix_rate(net, T, F.hₜ)
    params.functional_response.aᵣ = exp_ba_matrix_rate(net, T, F.aᵣ)
    params.producer_growth.K = exp_ba_vector_rate(net, T, F.K)
    params.environment.T = T
end

# The entry point for the user.
"""
    set_temperature!(p::ModelParameters, T, F!::TemperatureResponse)

Parametrize the given model given a temperature value
and the associated temperature_response.

```jldoctest
julia> fw = FoodWeb([0 0; 1 0]);
       model = ModelParameters(fw; functional_response = ClassicResponse(fw));
       model.temperature_response
NoTemperatureResponse

julia> model.biorates  # Default Biorates.
BioRates:
  d: [0.0, 0.0]
  r: [1.0, 0.0]
  x: [0.0, 0.314]
  y: [0.0, 8.0]
  e: (2, 2) sparse matrix

julia> set_temperature!(model, 25, ExponentialBA());
       model.temperature_response
Parameters for ExponentialBA response:
  r: ExponentialBAParams(1.5497531357028967e-7, 0.0, 0.0, -0.25, -0.25, -0.25, 0.0, 0.0, 0.0, -0.84)
  x: ExponentialBAParams(0.0, 6.557967639824989e-8, 6.557967639824989e-8, -0.31, -0.31, -0.31, 0.0, 0.0, 0.0, -0.69)
  aᵣ: ExponentialBAParams(0.0, 2.0452306245234897e-6, 2.0452306245234897e-6, 0.25, 0.25, 0.25, -0.8, -0.8, -0.8, -0.38)
  hₜ: ExponentialBAParams(0.0, 15677.784668089162, 15677.784668089162, -0.45, -0.45, -0.45, 0.47, 0.47, 0.47, 0.26)
  K: ExponentialBAParams(3.0, nothing, nothing, 0.28, 0.28, 0.28, 0.0, 0.0, 0.0, 0.71)

julia> model.biorates  # Biorates given this temperature response.
BioRates:
  d: [0.0, 0.0]
  r: [1.9446555905910437e-162, 0.0]
  x: [0.0, 3.7697909572935493e-135]
  y: [0.0, 8.0]
  e: (2, 2) sparse matrix
```
"""
function set_temperature!(p::ModelParameters, T, F!::TemperatureResponse)

    # error - can only be used with bioenergetic functional response
    if isa(F!, ExponentialBA) && !(isa(p.functional_response, ClassicResponse))
        type_response = typeof(p.functional_response)
        throw(
            ArgumentError("Temperature dependence isn't implented for '$type_response'. \
                          Use a functional response of type 'ClassicResponse' instead."),
        )
    end

    # Apply the functor to the parameters.
    F!(p, T)

    # Record which functor has been used for these parameters.
    p.temperature_response = F!

    p

end
