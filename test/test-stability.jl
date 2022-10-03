@testset "temporal stability as CV" begin


    # Test avg Population stability
    @test isnan(BEFWM2.avg_cv_sp([0 0; 0 0]))
    @test BEFWM2.avg_cv_sp([1 1; 1 1]) == 0
    @test BEFWM2.avg_cv_sp([0 0; 1 1])
    @test BEFWM2.avg_cv_sp([0 1; 1 0]) == BEFWM2.avg_cv_sp([0 0; 1 1]) == std([0 1]) * 2 / (.5 * 2)

    # Test synchrony
    @test BEFWM2.synchrony([0 1; 1 0]) ≈ 0
    @test BEFWM2.synchrony([0 0; 1 1]) ≈ 1

    # Test CV decompostion in population statibility and synchrony
    mat = rand(10,5)
    @test std(sum.(eachrow(mat))) / mean(sum.(eachrow(mat))) ≈ BEFWM2.avg_cv_sp(mat) * sqrt(BEFWM2.synchrony(mat))
    @test BEFWM2.temporal_cv(mat) ≈ BEFWM2.avg_cv_sp(mat) * sqrt(BEFWM2.synchrony(mat))
end
