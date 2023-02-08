@testset "temporal stability as CV" begin


    # Test avg Population stability
    @test isnan(EcologicalNetworksDynamics.avg_cv_sp([0 0; 0 0]))
    @test EcologicalNetworksDynamics.avg_cv_sp([1 1; 1 1]) == 0
    @test EcologicalNetworksDynamics.avg_cv_sp([0 0; 1 1])
    @test EcologicalNetworksDynamics.avg_cv_sp([0 1; 1 0]) ==
          EcologicalNetworksDynamics.avg_cv_sp([0 0; 1 1]) ==
          std([0 1]) * 2 / (0.5 * 2)

    # Test synchrony
    @test EcologicalNetworksDynamics.synchrony([0 1; 1 0]) ≈ 0
    @test EcologicalNetworksDynamics.synchrony([0 0; 1 1]) ≈ 1

    # Test CV decompostion in population statibility and synchrony
    mat = rand(10, 5)
    @test std(sum.(eachrow(mat))) / mean(sum.(eachrow(mat))) ≈
          EcologicalNetworksDynamics.avg_cv_sp(mat) *
          sqrt(EcologicalNetworksDynamics.synchrony(mat))
    @test EcologicalNetworksDynamics.temporal_cv(mat) ≈
          EcologicalNetworksDynamics.avg_cv_sp(mat) *
          sqrt(EcologicalNetworksDynamics.synchrony(mat))
end
