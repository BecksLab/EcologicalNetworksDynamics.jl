@testset "Build LogisticGrowth with producer competition" begin
    foodweb = FoodWeb([0 0 0; 0 0 0; 0 1 0]; quiet = true)

    g = LogisticGrowth(foodweb) # Default behavior.
    @test g.a == [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 0.0]

    g = LogisticGrowth(foodweb; a_ii = 1.0, a_ij = 2.0) # Set inter-specific competition.
    # Competition terms are 0 for all αij involving non-producers
    @test g.a == [1.0 2.0 0.0; 2.0 1.0 0.0; 0.0 0.0 0.0]

    # Custom competition matrix.
    my_competition_matrix = [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]
    g = LogisticGrowth(foodweb; a_matrix = my_competition_matrix, quiet = true)
    @test g.a == [1.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 0.0]

    # Should fail if non zero a for non-producers.
    message = "all(a_matrix[non_producer, :] .== 0)"
    @test_throws AssertionError(message) LogisticGrowth(
        foodweb,
        a_matrix = [1.0 1.0 0.0; 1.0 1.0 0.0; 1.0 0.0 0.0],
        quiet = true,
    )
    # Should fail if the `a_matrix` dimension does not match the size of the foodweb.
    message = "size(a_matrix, 1) == size(a_matrix, 2) == S"
    @test_throws AssertionError(message) LogisticGrowth(
        foodweb,
        a_matrix = [1.0 0.0; 1.0 0.0; 0.0 0.0],
        quiet = true,
    )
    message = "size(a_matrix, 1) == size(a_matrix, 2) == S"
    @test_throws AssertionError(message) LogisticGrowth(
        foodweb,
        a_matrix = [1.0 0.0; 1.0 0.0],
        quiet = true,
    )
end
