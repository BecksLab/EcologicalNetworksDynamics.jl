@testset "Assimilation efficiency" begin
    foodweb = FoodWeb([0 0 0; 1 0 0; 1 1 0])
    e_expect = sparse([0 0 0; 1 0 0; 1 2 0])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=1, e_carnivore=2) == e_expect
    e_expect = sparse([0 0 0; 3 0 0; 3 4 0])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=3, e_carnivore=4) == e_expect
    foodweb = FoodWeb([0 0 0; 1 1 0; 1 1 1])
    e_expect = sparse([0 0 0; 1 2 0; 1 2 2])
    @test BEFWM2.assimilation_efficiency(foodweb, e_herbivore=1, e_carnivore=2) == e_expect
end
