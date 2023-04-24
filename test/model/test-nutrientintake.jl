@testset "Logistic growth" begin

    #=
    OBJECT CONSTRUCTION
    =#

    # default
    foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0])
    ni = NutrientIntake(foodweb)

    # check default values
    @test ni.n == 2 #defult is 2 nutrients
    @test ni.D == 0.25 
    @test ni.Sₗ == [10.0, 10.0]
    @test ni.Cₗᵢ == sparse([1 0.5 ; 1 0.5])
    @test ni.Kₗᵢ == [1.0 1 ; 1 1 ; nothing nothing]

    # passing custom values - n changes the dimensions of C, S, and K
    ni = NutrientIntake(foodweb, n = 3, Kₗᵢ = 10, D = 0.8, Sₗ = 4, Cₗᵢ = [0.4, 0.1, 0.5])
    @test ni.n == 3 
    @test ni.D == 0.8 
    @test ni.Sₗ == repeat([4.0], ni.n)
    @test ni.Cₗᵢ == sparse([0.4 0.1 0.5 ; 0.4 0.1 0.5])
    @test ni.Kₗᵢ == [10.0 10.0 10.0 ; 10.0 10.0 10.0 ; nothing nothing nothing]

    # passing custom values 
    ni1 = NutrientIntake(foodweb, n = 4, Kₗᵢ = [1, 1], Sₗ = [1, 1, 1, 1], Cₗᵢ = [0.2, 0.2, 0.2, 0.2])
    ni2 = NutrientIntake(foodweb, n = 4, Kₗᵢ = ones(2,4), Sₗ = ones(4), Cₗᵢ = fill(0.2, 2, 4))
    ni3 = NutrientIntake(foodweb, n = 4, Kₗᵢ = ones(3,4))
    @test ni1.n == ni2.n == ni3.n == 4 
    @test ni1.D == ni2.D == ni3.D == 0.25
    #   - K has dimenion #species, #nutrients (K == nothing for non prod.)
    @test ni1.Kₗᵢ == ni2.Kₗᵢ == ni3.Kₗᵢ == 
        [1.0     1.0     1.0     1.0    ;
         1.0     1.0     1.0     1.0    ; 
         nothing nothing nothing nothing]
    #   - Sₗ has dimension #producer, #nutrient
    @test ni1.Sₗ  == ni2.Sₗ  == 
        [1.0, 1.0, 1.0, 1.0]
    #   - Cₗᵢ has dimension #producer, #nutrient
    @test ni1.Cₗᵢ  == ni2.Cₗᵢ  == 
        fill(0.2, 2, 4)

    # Error for wrong dimensions
    @test_throws ArgumentError NutrientIntake(foodweb, Kₗᵢ = [1,1,1])
    @test_throws ArgumentError NutrientIntake(foodweb, Kₗᵢ = [1 1 1 ; 1 1 1])
    @test_throws ArgumentError NutrientIntake(foodweb, Sₗ = [1 1 1])
    @test_throws ArgumentError NutrientIntake(foodweb, Cₗᵢ = [1 1 1])
    @test_throws ArgumentError NutrientIntake(foodweb, n = 3, Cₗᵢ = [1 1 ; 1 1 ; 1 1])
    
    #=
    GROWTH FUNCTION
    =#
    
    #If N = 0, growth is null 
    S = richness(foodweb) 
    B = ones(S)
    r = BioRates(foodweb).r
    N = zeros(2)
    ni = NutrientIntake(foodweb)

    @test ni(1, B, r, foodweb, N) == 0.0
    @test ni(2, B, r, foodweb, N) == 0.0
    
    # Sanity check:
    #If N != 0, growth is positive for default values and dependent on B
    N = ones(2)
    B = [3,2,1]
    @test ni(1, B, r, foodweb, N) > ni(2, B, r, foodweb, N) > 0.0
    # Still 0 for non producers though
    @test ni(3, B, r, foodweb, N) == 0

    # Test a specific case
    N = [2.5, 3.2]
    B = [0.3, 0.5, 0.2]
    ni = NutrientIntake(foodweb, Kₗᵢ = [1.2, 3.6])
    exp1 = r[1] * B[1] * minimum(N ./ (ni.Kₗᵢ[1,:] .+ N))
    exp2 = r[2] * B[2] * minimum(N ./ (ni.Kₗᵢ[2,:] .+ N))
    exp3 = 0
    @test ni(1, B, r, foodweb, N) == exp1
    @test ni(2, B, r, foodweb, N) == exp2
    @test ni(3, B, r, foodweb, N) == exp3
    
    #=
    DYNAMICS
    =# 

    # Sanity check: 
    # consumers goes extinct if supply is null
    # (producer don't because there are no metabolic losses or mortality outside of consumption)
    foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0])
    ni = NutrientIntake(foodweb, Sₗ = 0.0)
    S = richness(foodweb) 
    p = ModelParameters(foodweb, producer_growth = ni)
    B0 = ones(S)
    sim = simulate(p, B0)

    @test sim[end][2:3] == [0.0, 0.0]

    #in the absence of consumers, all biomasses are equal (for equal growth parameters)
    foodweb = FoodWeb([0 0 ; 0 0])
    ni = NutrientIntake(foodweb)
    p = ModelParameters(foodweb, producer_growth = ni)
    sim = simulate(p, ones(2))

    @test all(getindex.(sim.u,  1) .== getindex.(sim.u,  2))

    #Kₗᵢ sets the hierarchy of competition between producers 
    ni = NutrientIntake(foodweb, Kₗᵢ = [0.1 0.1 ; 0.5 0.5]) #smaller value = better
    p = ModelParameters(foodweb, producer_growth = ni)
    sim = simulate(p, ones(2))

    @test sim[end][1] > sim[end][2]
end