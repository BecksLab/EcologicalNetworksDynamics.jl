# Rough measures of performance improvements with specialized dBdt! code generation.

print("Loading packages.. ")
flush(stdout)
@time begin
    using EcologicalNetworksDynamics
    using DiffEqBase
    using DiffEqCallbacks
    using EcologicalNetworks
    using Formatting
    using Random
    using DataStructures
    fitin = EcologicalNetworksDynamics.fitin
    cpad = EcologicalNetworksDynamics.cpad
end

# Collect output of @timed macros into this global structure.
# Indexing:
#   - FunctionalResponse
#   - (situation, S)
#   - tlim
#   - code generation style (:generic, :raw, :compact)
measures = Dict()

function record(key, value)
    haskey(measures, key) || (measures[key] = [])
    push!(measures[key], value)
end

function small_foodweb(S, FR)
    foodweb = FoodWeb([
        0 0 0 0
        0 0 1 0
        1 0 0 0
        0 1 0 0
    ])
    (EcologicalNetworksDynamics.richness(foodweb) != S) &&
        throw("Actual foodweb does not involve $S species.")
    parms = ModelParameters(foodweb; functional_response = FR(foodweb))
    B0 = [0.5, 0.5, 0.5, 0.5]
    parms, B0
end

function large_foodweb(S, FR)
    Random.seed!(12)
    foodweb = FoodWeb(nichemodel, S; C = 0.04)
    parms = ModelParameters(foodweb; functional_response = FR(foodweb))
    B0 = repeat([0.5], S)
    parms, B0
end

# Group scenarios checking so varying tlims are all checked in a row.
# (this avoid useless recompilations of generated functions)
# For every scenario, compare generic code to the various codegen styles,
# both for performance and correctness.
function check_scenario(FR, (situation, S), tlims)
    styles = [:raw, :compact]

    print("Parametrize.. ")
    flush(stdout)
    @time parms, B0 = situation(S, FR)

    print("Single invocation of generic code.. ")
    flush(stdout)
    expected_dB = [v for v in B0]
    @time EcologicalNetworksDynamics.dBdt!(expected_dB, B0, (parms, Dict()), 0)

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
        @time Base.invokelatest(dbdt, actual_dB, B0, (data, Dict()), 0)

        print("Check consistency with basic generic invocation.. ")
        flush(stdout)
        all(actual_dB .≈ expected_dB) || error("Inconsistent!")
        println("ok.")

        codes[gen_style] = dbdt
        datas[gen_style] = data
    end

    time_simulate(style, tlim, code, data) = begin
        for i in 1:2 #  Run twice to get rid of compilation effects.
            GC.gc() #  Attempt to measure least gc.
            # Measure compile time by hand since it seems that @time does but not @timed :(
            # https://github.com/JuliaLang/julia/issues/47056
            Base.cumulative_compile_timing(true)
            compile_tic = Base.cumulative_compile_time_ns()
            @time sol, measure... = @timed simulate(
                parms,
                B0;
                tmax = tlim,
                diff_code_data = (code, data),
                callback = CallbackSet(PositiveDomain()), #  Don't stop before tmax.
            )
            compile_toc = Base.cumulative_compile_time_ns()
            Base.cumulative_compile_timing(false)
            compile_duration = sum(compile_toc .- compile_tic)
            # Record both but only return last.
            record((FR, (situation, S), tlim, style), (compile_duration, measure))
            i == 2 && return sol
        end
    end

    for (i, tlim) in enumerate(tlims)
        println("\n- - - tlim = $(format(tlim, commas=true)) - - -")
        println("Simulate with generic code..")
        expected_solution =
            time_simulate(:generic, tlim, EcologicalNetworksDynamics.dBdt!, parms)
        # Only check consistency the first time
        # to not keep heavily large simulation results around when tlim gets high.
        if i > 1
            expected_solution = nothing
        end

        for gen_style in styles
            println("\nSimulate with :$gen_style generated code..")
            actual_solution =
                time_simulate(gen_style, tlim, codes[gen_style], datas[gen_style])

            if i > 1
                actual_solution = nothing
                continue
            end
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

# Run all chosen scenarios now to collect measures.
small = (small_foodweb, 4)
large = (large_foodweb, 100)
scenarios = [
    (LinearResponse, small, [100, 1e6, 5e6])
    (LinearResponse, large, [100, 1e5, 5e5])
    (ClassicResponse, small, [100, 1e5, 1e6])
    (ClassicResponse, large, [100, 2e3, 2e4])
    (BioenergeticResponse, small, [100, 1e5, 1e6])
    (BioenergeticResponse, large, [100, 2e3, 2e4])
]

for (FR, (situation, S), tlims) in scenarios
    println(repeat("=", 80))
    println("$FR, $situation, S=$S")
    check_scenario(FR, (situation, S), tlims)
    println(repeat("=", 80))
end
GC.gc()


# Restitute in a more compact way.
bold = "\033[1m"
blue = "\033[34m"
red = "\033[31m"
reset = "\033[0m"
# Setup column sizes (excluding separators)
stylew = 9 # code style
compilew = 8 # compilation time
runw = 8   # solve/record time
speedupw = 7 # speedup factor
tlimw = compilew + runw + speedupw + 2
# Outer loops force iteration order,
# while inner loops over the measures collection just filters out relevant entries.
# Largest groups are functional response types.
for FR in (LinearResponse, ClassicResponse, BioenergeticResponse)
    println(bold * rpad(repeat("-", 5) * " $FR ", 90, "-") * reset)
    # Then, the situation / network size.
    for (situation, S) in (small, large)
        println("$(bold)S = $S$reset")
        # At this point, values of tlim should be consistent accross "columns",
        # take this opportunity to collect measures into a more usefully indexed "table".
        table = SortedDict() # Nested dicts with tlim.style.measure ↦ value
        for ((fr, (sit, s), tlim, style), meas) in measures
            fr == FR && situation == sit && S == s || continue
            haskey(table, tlim) || (table[tlim] = Dict())
            haskey(table[tlim], style) || (table[tlim][style] = Dict())
            table[tlim][style][:compile] = comp = sum(first.(meas)) / 1e9
            # For some reason, small values are sometimes negative :\
            table[tlim][style][:run] =
                max(sum(map(m -> last(m).time, meas)) - comp, 0) / length(meas)
        end
        # Header lines.
        header = [repeat(" ", stylew) * "|" for _ in 1:2]
        for tlim in keys(table)
            header[1] *= cpad("tlim = " * format(tlim; commas = true), tlimw) * "|"
            header[2] *= cpad("comp.", compilew) * "|"
            header[2] *= cpad("run", runw) * "|"
            header[2] *= cpad("speed", speedupw) * "|"
        end
        println.(header)
        # Data lines.
        runref = Dict() # tlim ↦ runtime for :generic code
        compref = Dict() # same for compilation.
        for style in (:generic, :raw, :compact)
            print(rpad(":$style", stylew) * "|")
            for (tlim, data) in table
                data = data[style]
                haskey(runref, tlim) || (runref[tlim] = data[:run])
                haskey(compref, tlim) || (compref[tlim] = data[:compile])
                rel = (cp = data[:compile]) / compref[tlim]
                hi = isnan(rel) ? "" : (rel > 10) ? bold * red : (rel > 1.2) ? red : ""
                print(hi * cpad(fitin(cp, compilew - 3) * "s", compilew) * "$reset|")
                print(cpad(fitin(data[:run], runw - 3) * "s", runw) * "|")
                sp = runref[tlim] / data[:run]
                isnan(sp) && (sp = 1)
                hi = (sp > 10) ? bold * blue : (sp > 1.1) ? blue : (sp > 0.9) ? "" : red
                print(hi * cpad("× " * fitin(sp, speedupw - 4), speedupw) * "$reset|")
            end
            println()
        end
        println()
    end
end
