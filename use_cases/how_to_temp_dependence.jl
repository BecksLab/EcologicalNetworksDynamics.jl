# generate food FoodWeb
A = [0 0 0; 1 0 0; 0 1 0]
foodweb = FoodWeb(A)

# generate model parameters using classic response (not yet implemented for bioenergetic rates)
params = ModelParameters(foodweb, functional_response = ClassicResponse(foodweb))

# checking unstressed rates
params.biorates.r # 1.0, 0.0, 0.0
params.biorates.x # 0.0, 0.314, 0.314
params.functional_response.aᵣ # 0.5
params.functional_response.hₜ # 1.0
params.environment.K # 1 nothing nothing
params.environment.T # 293.15
params.temperature_response # NoTemperatureResponse() - default 


#### Temperature dependence 
temp = 300.15 # temperature in Kelvin

# use set_temperature! to change the rates in params using Exponential Boltzmann-Arrhenius 
set_temperature!(params, temp, ExponentialBA()) 

# checking new rates
params.biorates.r # 1.346, 0.0, 0.0
params.biorates.x # 0.0, 0.496, 0.496
params.functional_response.aᵣ # 11.6189
params.functional_response.hₜ #  4.9328e10
params.environment.K # 4.574e10 0.0 0.0
params.environment.T # 305.15
params.temperature_response # NoTemperatureResponse() - default 


# these are calculated internally using the exponentialBA_matrix_rate and exponentialBA_vector_rate functions 
r = exponentialBA_vector_rate(foodweb, temp, BEFWM2.DefaultExpBAGrowthParams())
aᵣ = exponentialBA_matrix_rate(foodweb, temp, BEFWM2.DefaultExpBAAttackRateParams())




#### customisation - 🚧 IN PROGRESS 🚧
# you can also create your own custom set of parameters to use for specific rates
custom_r_BAParams = ExponentialBAParams(1, 0, 0, 1, 0, 0, 0, 0, 0, 0.5)
custom_x_BAParams = ExponentialBAParams(0, 1, 1, 0, 1, 0.5, 0, 0, 0, 0.8)
custom_aᵣ_BAParams = ExponentialBAParams(0, 1, 1, 0, 1, 0.5, -1, -2, -2, -1)
custom_hₜ_BAParams = ExponentialBAParams(0, 1, 1, -1, -1, -0.5, 1, 2, 2, 1)
custom_K_BAParams = ExponentialBAParams(2, 0, 0, 1, 0, 0.9, 1, 2, 2, 0.5)

# compile params into an ExponentialBA <: TemperatureResponse
custom_response = BEFWM2.ExponentialBA(custom_r_BAParams,
custom_x_BAParams, 
custom_aᵣ_BAParams,
custom_hₜ_BAParams,
custom_K_BAParams)

typeof(custom_response) # ExponentialBA

##### This doesn't work - need to adjust set_temperature!() functor to take sets of custom ExponentialBA parameters
# Actually probably need to change ExponentialBA function in temperature_dependent_rates.jl l:99
set_temperature!(params, temp, custom_response)