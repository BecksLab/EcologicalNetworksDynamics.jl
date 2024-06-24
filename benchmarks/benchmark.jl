using EcologicalNetworksDynamics
using LinearAlgebra

S = 10
A = zeros(Int64, S, S) # No trophic interaction.
alpha = fill(0.1, (S, S)) # Competitive interaction among producers.
alpha[diagind(alpha)] .= 1

foodweb = Foodweb(A)

model = default_model(foodweb, LogisticGrowth(; producers_competition = alpha))
B0 = 0.5 .+ rand(S)
t_max = 100_000

# Simulation time - First call.
@time simulate(model, B0, t_max); # Time to first call ~ 3 seconds on a MacBook Pro M1.

# Simulation time - After first call.
@time simulate(model, B0, t_max); # Even faster ~ 0.1 seconds.
