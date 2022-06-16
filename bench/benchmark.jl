# Rough measures of performance improvements with specialized dBdt! code generation.

println("Loading packages..")
@time begin
    using BEFWM2
    using BenchmarkTools
    using DiffEqBase
    using DiffEqCallbacks
    using EcologicalNetworks
    using Random
end

function small_foodweb_long_simulation()
    foodweb = FoodWeb([
        0 0 0 0
        0 0 1 0
        1 0 0 0
        0 1 0 0
    ])
    parms = ModelParameters(foodweb)
    B0 = [0.5, 0.5, 0.5, 0.5]
    tlims = [100, 100_000, 1_000_000]
    parms, B0, tlims
end

function large_foodweb_short_simulation()
    Random.seed!(12)
    S = 35 # ←  ⚠ time is exploding with eg. S=60 at compilation time, but speedup is great.
    foodweb = FoodWeb(nichemodel, S; C = 0.2)
    parms = ModelParameters(foodweb)
    B0 = repeat([0.5], S)
    tlims = [100, 5_000, 50_000]
    parms, B0, tlims
end

function check(situation)
    println("Parametrize..")
    @time parms, B0, tlims = situation()

    println("Generate/evaluate expression..")
    @time dbdt = eval(generate_dbdt(parms))

    act_state = [v for v in B0]
    exp_state = [v for v in B0]
    println("Compile expression..") #  ↓ ⚠  occasionally takes forever.
    @time Base.invokelatest(dbdt, act_state, B0, parms, 0)

    print("Check basic consistence of generic/specialized code on simple invocation..")
    flush(stdout)
    BEFWM2.dBdt!(exp_state, B0, parms, 0)
    all(act_state .≈ exp_state) || error("Inconsistent!")
    println(" ok.")

    println("\n- - - Measure basic perfs - - -")
    for tlim in tlims
        println("tlim=$tlim:")
        solutions = []
        for df in [BEFWM2.dBdt!, dbdt]
            println("$(df == dbdt ? "Specialized" : "Generic") code:")
            for _ in 1:2 #  Run twice to get rid of compilation effects.
                GC.gc() #  Attempt to measure least gc.
                @time sol = simulate(
                    parms,
                    B0;
                    tmax = tlim,
                    diff_function = df,
                    callback = CallbackSet(PositiveDomain()), #  Don't stop before tmax.
                )
                push!(solutions, sol)
            end
        end
        print("Check solutions consistency..")
        flush(stdout)
        for i in 1:(length(solutions)-1)
            for j in (i+1):length(solutions)
                a, b = solutions[i], solutions[j]
                all([a.retcode == b.retcode, a.k ≈ b.k, a.t ≈ b.t, a.u ≈ b.u]) ||
                    error("Inconsistent solutions $i and $j!")
                GC.gc()
            end
        end
        println(" ok.")
    end
end

println("\n===== Small foodweb, long simulation time ===== ")
check(small_foodweb_long_simulation)

println("\n===== Large foodweb, short simulation time ===== ")
check(large_foodweb_short_simulation)
