# Rough measures of performance improvements with specialized dBdt! code generation.

print("Loading packages.. ")
flush(stdout)
@time begin
    using BEFWM2
    using BenchmarkTools
    using DiffEqBase
    using DiffEqCallbacks
    using EcologicalNetworks
    using Formatting
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
    S = 35 #  ⚠  very long to compile with eg. S=60 and type = :raw.
    foodweb = FoodWeb(nichemodel, S; C = 0.2)
    parms = ModelParameters(foodweb)
    B0 = repeat([0.5], S)
    tlims = [100, 5_000, 50_000]
    parms, B0, tlims
end

function check(situation)
    styles = [:raw, :compact]

    print("Parametrize.. ")
    flush(stdout)
    @time parms, B0, tlims = situation()

    print("Single invocation of generic code.. ")
    flush(stdout)
    expected_dB = [v for v in B0]
    @time BEFWM2.dBdt!(expected_dB, B0, parms, 0)

    codes = Dict()
    datas = Dict()
    for gen_style in styles
        println("\nSpecialized :$gen_style expression..")
        print("Generate: ")
        flush(stdout)
        @time begin
            xp, data = generate_dbdt(parms, gen_style)
            dbdt = eval(xp)
        end

        actual_dB = [v for v in B0]
        print("Compile:  ") #  ↓ ⚠  takes forever with too big :raw generated code.
        flush(stdout)
        @time Base.invokelatest(dbdt, actual_dB, B0, data, 0)

        print("Check consistency with basic generic invocation.. ")
        flush(stdout)
        all(actual_dB .≈ expected_dB) || error("Inconsistent!")
        println("ok.")

        codes[gen_style] = dbdt
        datas[gen_style] = data
    end

    time_simulate(tlim, code, data) = begin
        for i in 1:2 #  Run twice to get rid of compilation effects.
            GC.gc() #  Attempt to measure least gc.
            @time sol = simulate(
                parms,
                B0;
                tmax = tlim,
                diff_code_data = (code, data),
                callback = CallbackSet(PositiveDomain()), #  Don't stop before tmax.
            )
            if i == 2
                return sol
            end
        end
    end

    for tlim in tlims
        println("\n- - - tlim = $(format(tlim, commas=true)) - - -")
        println("Simulate with generic code..")
        expected_solution = time_simulate(tlim, BEFWM2.dBdt!, parms)

        for gen_style in styles
            println("\nSimulate with :$gen_style generated code..")
            actual_solution = time_simulate(tlim, codes[gen_style], datas[gen_style])

            print("Check consistency with generic code.. ")
            flush(stdout)
            e = expected_solution
            a = actual_solution
            all([a.retcode == e.retcode, a.k ≈ e.k, a.t ≈ e.t, a.u ≈ e.u]) ||
                error("Inconsistent solutions!")
            println("ok.")
        end
    end
end

println("\n===== Small foodweb, long simulation time =====")
check(small_foodweb_long_simulation)

println("\n\n===== Large foodweb, short simulation time =====")
check(large_foodweb_short_simulation)
