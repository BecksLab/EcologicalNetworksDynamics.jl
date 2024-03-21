using EcologicalNetworksDynamics
using EcologicalNetworks
using LinearAlgebra
using Statistics
using Test

S = 30
C = 0.1
n_rep = 10_000 # Number of replicates.

@testset "New implementation of cascade and niche model" begin

    niche_model_old(S, C) = nichemodel(S, C).edges
    cascade_model_old(S, C) = cascademodel(S, C).edges
    old_functions = [niche_model_old, cascade_model_old]
    new_functions = [niche_model, cascade_model]
    n_producers(A) = count(==(0), sum(A; dims = 2) .== 0)
    n_cannibals(A) = count(==(1), A[diagind(A)])
    tl = EcologicalNetworksDynamics.Internals.trophic_levels
    mean_tl(A) = mean(tl(A))
    max_tl(A) = maximum(tl(A))
    property_to_test = [n_producers, n_cannibals, mean_tl, max_tl]
    for (old_f, new_f) in zip(old_functions, new_functions)
        for prop in property_to_test
            p_new = mean([prop(new_f(S, C)) for _ in 1:n_rep])
            p_old = mean([prop(old_f(S, C)) for _ in 1:n_rep])
            @test p_new ≈ p_old atol = 0.1
        end
    end

end
