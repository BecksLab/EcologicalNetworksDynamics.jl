module TestAliasingDicts

using EcologicalNetworksDynamics.AliasingDicts
using Main: @argfails, @aliasfails, @failswith
using Test

const AD = AliasingDicts

# Leverage `repr` summarize most tested features within a single string comparison.
macro check(xp, expected, type)
    quote
        d = $(esc(xp))
        @test $expected == repr(d)
        @test d isa FruitDict{$type}
    end
end

@testset "Aliased references" begin

    #---------------------------------------------------------------------------------------
    # Test internal aliasing system.

    al = AD.AliasingSystem("fruit", :fruit, (:apple => [:ap, :a], :pear => [:p, :pe]))
    @test length(al) == 2

    # Original order is conserved.
    @test [s for s in AD.standards(al)] == [:apple, :pear]

    # Shortest then lexicographic.
    @test [r for r in AD.references(al)] == [:a, :ap, :apple, :p, :pe, :pear]

    # Cheat-sheet.
    @test AD.aliases(al) == AD.OrderedDict(:apple => [:a, :ap], :pear => [:p, :pe])

    @test AD.name(al) == "fruit"

    @test AD.standardize('p', al) == :pear
    @test AD.standardize(:ap, al) == :apple

    # Test references equivalence.
    @test AD.is(:pe, :pear, al)
    @test !AD.is(:a, :pear, al)

    # Find in iterable.
    @test AD.isin(:p, (:pear, :apple), al)

    @test AD.shortest(:apple, al) == :a

    # Guard against invalid or ambiguous referencing.
    @aliasfails(AD.standardize(:xy, al), "fruit", "Invalid fruit name: 'xy'.")
    @aliasfails(
        AD.AliasingSystem("fruit", :fruit, ("peach" => ['p', 'h'], "pear" => ['r', 'p'])),
        "fruit",
        "Ambiguous fruit reference: 'p' either means 'peach' or 'pear'.",
    )
    @aliasfails(
        AD.AliasingSystem("fruit", :fruit, ("peach" => ['h', 'e'], "pear" => ['p', 'p'])),
        "fruit",
        "Duplicated fruit alias for 'pear': 'p'.",
    )

    #---------------------------------------------------------------------------------------
    # Construct an actual "AliasDict" type,
    # with all associated methods,
    # from an aliasing system.
    @aliasing_dict(FruitDict, "fruit", :fruit, (:apple => [:a], :berry => [:b, :br]))

    # Fit into the type system.
    @test FruitDict <: AbstractDict
    @test FruitDict{Any} <: AbstractDict{Symbol,Any}
    @test FruitDict{Int64} <: AbstractDict{Symbol,Int64}

    # Construct with or without an explicit type, concrete or abstract.
    # If heterogeneous, the values type is inferred to the less abstract common type.
    # Keys are implicitly converted to symbols if possible.

    # Empty.
    @check FruitDict() "$FruitDict{Any}()" Any
    @check FruitDict{Int64}() "$FruitDict{Int64}()" Int64
    @check FruitDict{Real}() "$FruitDict{Real}()" Real

    # With single kwarg.
    @check FruitDict(; a = 5.0) "$FruitDict{Float64}(a: 5.0)" Float64
    @check FruitDict{Int64}(; a = 5.0) "$FruitDict{Int64}(a: 5)" Int64 # (conversion)
    @check FruitDict{Real}(; a = 5.0) "$FruitDict{Real}(a: 5.0)" Real # (retained abstract)

    # With single arg.
    @check FruitDict(:a => 5.0) "$FruitDict{Float64}(a: 5.0)" Float64
    @check FruitDict('a' => 5.0) "$FruitDict{Float64}(a: 5.0)" Float64
    @check FruitDict{Int64}(:a => 5.0) "$FruitDict{Int64}(a: 5)" Int64
    @check FruitDict{Int64}('a' => 5.0) "$FruitDict{Int64}(a: 5)" Int64 # (key conversion)
    @check FruitDict{Real}(:a => 5.0) "$FruitDict{Real}(a: 5.0)" Real
    @check FruitDict{Real}("a" => 5.0) "$FruitDict{Real}(a: 5.0)" Real# (key conversion)

    # With double kwargs.
    @check FruitDict(; a = 5, b = 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real
    @check FruitDict{Int64}(; a = 5, b = 8.0) "$FruitDict{Int64}(a: 5, b: 8)" Int64
    @check FruitDict{Real}(; a = 5, b = 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real

    # With double args.
    @check FruitDict(:a => 5, :b => 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real
    @check FruitDict('a' => 5, "b" => 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real
    @check FruitDict{Int64}(:a => 5, :b => 8.0) "$FruitDict{Int64}(a: 5, b: 8)" Int64
    @check FruitDict{Int64}('a' => 5, "b" => 8.0) "$FruitDict{Int64}(a: 5, b: 8)" Int64
    @check FruitDict{Real}(:a => 5, :b => 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real
    @check FruitDict{Real}('a' => 5, "b" => 8.0) "$FruitDict{Real}(a: 5, b: 8.0)" Real

    # Guard against ambiguities.
    @aliasfails(
        FruitDict(:a => 5, :b => 8.0, :berry => 7.0),
        "fruit",
        "Fruit type 'berry' specified twice: once with 'b' and once with 'berry'.",
    )

    # Entries are (re)-ordered to standard order.
    @test collect(keys(FruitDict(; b = 8.0, a = 5))) == [:apple, :berry]

    # Index with anything consistent.
    d = FruitDict(:a => 5, :b => 8)
    @test (d[:a], d[:apple], d['a'], d["apple"]) == (5, 5, 5, 5)

    # Set values.
    d[:a] = 42
    @test d[:apple] == 42

    @test haskey(d, :b)
    @test haskey(d, :berry)

    # Guard against inconsistent entries.
    @aliasfails(d[:xy], "fruit", "Invalid fruit name: 'xy'.")

    # Access underlying aliasing system methods from the instance..
    @test AD.name(d) == "fruit"
    @test collect(AD.references(d)) == [:a, :apple, :b, :br, :berry]
    @test collect(AD.references(:br, d)) == [:b, :br, :berry]
    @test (:b in AD.references(d), :xy in AD.references(d)) == (true, false)
    @test AD.shortest(:berry, d) == :b
    @test (AD.standardize(:br, d), AD.standardize(:apple, d)) == (:berry, :apple)

    # .. or from the type itself.
    @test AD.name(FruitDict) == "fruit"
    @test collect(AD.references(FruitDict)) == [:a, :apple, :b, :br, :berry]
    @test collect(AD.references(:br, FruitDict)) == [:b, :br, :berry]
    @test (:b in AD.references(FruitDict), :xy in AD.references(FruitDict)) == (true, false)
    @test AD.shortest(:berry, FruitDict) == :b
    @test (AD.standardize(:br, FruitDict), AD.standardize(:apple, FruitDict)) ==
          (:berry, :apple)

end

# These two need to live in global space for the next test set.
function check_mix_arguments(all_args, implicit_fruit, implicit_prop)
    given(fruit, prop) = haskey(all_args[fruit], prop)
    if given(:a, :c) && given(:b, :d)
        all_args[:apple][:color][2] == "red" && all_args[:berry][:depth][2] < 10 ||
            throw(ArgumentError("Berry too deep for a red apple."))
    end
end
mix_types = nothing

# ==========================================================================================
@testset "Nested 2D API" begin

    # Nest fruit and properties.
    @aliasing_dict(FruitDict, "fruit", :fruit, (:apple => [:a], :berry => [:b, :br]))
    @aliasing_dict(PropertyDict, "property", :prop, (:color => [:c, :col], :depth => [:d]))

    # Specify type template.
    F, P = FruitDict, PropertyDict
    global mix_types = F(;
        apple = P(; color = String, depth = Float64),
        berry = P(; color = Symbol, depth = Int64),
    )

    @prepare_2D_api(Mix, FruitDict, PropertyDict)

    # These are now defined.
    MA = MixArguments
    TD = TrackedPropDict{Any} # (happens to be the common 'common type' per fruit)
    nocontext(; kwargs...) = parse_mix_arguments(kwargs)
    with_prop(p; kwargs...) = parse_fruit_for_prop(p, kwargs)
    with_fruit(f; kwargs...) = parse_prop_for_fruit(f, kwargs)

    BA = AD.BasalArg{F,P}
    RB = AD.RevBasalArg{F,P}
    NA = AD.NestedArg{F,P}
    RN = AD.RevNestedArg{F,P}
    OC = AD.OuterContextArg{F,P}
    IC = AD.InnerContextArg{F,P}

    # No arguments yield empty data with correct structure.
    @test nocontext() == MA(; apple = TD(), berry = TD())

    # Index 2D information via arguments name.
    @test nocontext(; a_col = :red) == MA(;
        apple = TD(; color = (BA(:a, :col), "red")), # <- Information stored/converted here,
        berry = TD(),         # ^^^^^^^^^^--------------- recalling how it has been input.
    )
    # Synonym (reversed base argument).
    @test nocontext(; col_a = :red) ==
          MA(; apple = TD(; color = (RB(:a, :col), "red")), berry = TD())

    # Target another "cell" in this (fruit × property) "matrix".
    @test nocontext(; a_col = :red, depth_berry = 5) == MA(;
        apple = TD(; color = (BA(:a, :col), "red")),
        berry = TD(; depth = (RB(:berry, :depth), 5)), # <- New.
    )

    # Target several cells at once (fruit-wise).
    @test nocontext(; apple = (col = :red, d = 5)) == MA(;
        apple = TD(; color = (NA(:apple, :col), "red"), depth = (NA(:apple, :d), 5)),
        berry = TD(),
    )

    # Target several cells at once (property-wise).
    @test nocontext(; color = (a = :red, br = :blue)) == MA(;
        apple = TD(; color = (RN(:a, :color), "red")),
        berry = TD(; color = (RN(:br, :color), :blue)),
    )

    # Also works with dynamic dict form.
    dyn = Dict(:col => :red, :d => 5)
    @test nocontext(; apple = dyn) == MA(;
        apple = TD(; color = (NA(:apple, :col), "red"), depth = (NA(:apple, :d), 5)),
        berry = TD(),
    )
    dyn = Dict(:a => 5, :br => 5)
    @test nocontext(; depth = dyn) == MA(;
        apple = TD(; depth = (RN(:a, :depth), 5)),
        berry = TD(; depth = (RN(:br, :depth), 5.0)),
    )

    # Simpler "1D" forms with implicit fruit/property.
    # With inner context.
    args = with_prop(:d; a = 5, b = 5)
    @test args == FruitDict(; apple = (IC(:a, :d), 5.0), berry = (IC(:b, :d), 5))
    # Correct minimal promotion and types.
    @test typeof(args).parameters[1].parameters[2] === Real
    @test typeof(args[:a][2]) === Float64
    @test typeof(args[:b][2]) === Int64

    # With outer context.
    args = with_fruit(:b; c = "blue", d = 5)
    @test args == PropertyDict(; color = (OC(:b, :c), :blue), depth = (OC(:b, :d), 5))
    @test typeof(args).parameters[1].parameters[2] === Any
    @test typeof(args[:c][2]) === Symbol
    @test typeof(args[:d][2]) === Int64

    #---------------------------------------------------------------------------------------
    # Guard against invalid input.

    @argfails(
        nocontext(x = 5),
        "Could not recognize 'fruit' or 'property' within argument name 'x'.",
    )
    @aliasfails(with_prop(:x, a = 5), "property", "Invalid property name: 'x'.",)
    @aliasfails(with_prop(:a, b = 5), "property", "Invalid property name: 'a'.",)
    @aliasfails(with_fruit(:x, d = 5), "fruit", "Invalid fruit name: 'x'.",)
    @aliasfails(with_fruit(:c, d = 5), "fruit", "Invalid fruit name: 'c'.",)

    @argfails(
        nocontext(apple = 5),
        "Fruit argument 'apple' cannot be iterated as (property=value,) pairs.",
    )

    @argfails(
        with_fruit(:apple, color = (a = 5,)),
        "Could not convert or adapt input at (:apple, :color) from 'color' argument \
         with value: (a = 5,).\n\
         Expected type   : String\n\
         Received instead: NamedTuple{(:a,), Tuple{Int64}}",
    )

    @argfails(
        with_prop(:color, apple = (a = 5,)),
        "Could not convert or adapt input at (:apple, :color) from 'apple' argument \
         with value: (a = 5,).\n\
         Expected type   : String\n\
         Received instead: NamedTuple{(:a,), Tuple{Int64}}",
    )

    @aliasfails(nocontext(color = (x = 5,)), "fruit", "Invalid fruit name: 'x'.",)

    @aliasfails(
        nocontext(apple = (berry = 5,)),
        "property",
        "Invalid property name: 'berry'.",
    )

    @aliasfails(nocontext(color = (depth = 5,)), "fruit", "Invalid fruit name: 'depth'.",)

    @argfails(
        nocontext(apple = (color = :red)),
        "Fruit argument 'apple' cannot be iterated as (property=value,) pairs.",
    )

    # Catch redundant specifications.
    @argfails(
        nocontext(apple = (color = :red, c = :blue)),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'c' within a 'apple' argument, \
         but it has already been specified \
         as 'color' within a 'apple' argument. \
         Consider removing either one.",
    )

    @argfails(
        nocontext(apple = (color = :red,), c = (a = :blue,)),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'a' within a 'c' argument, \
         but it has already been specified \
         as 'color' within a 'apple' argument. \
         Consider removing either one.",
    )

    @argfails(
        nocontext(apple = (color = :red,), a = (c = :blue,)),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'c' within a 'a' argument, \
         but it has already been specified \
         as 'color' within a 'apple' argument. \
         Consider removing either one.",
    )

    @argfails(
        nocontext(apple = (color = :red,), c_a = :blue),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'c_a' argument, \
         but it has already been specified \
         as 'color' within a 'apple' argument. \
         Consider removing either one.",
    )

    @argfails(
        nocontext(apple = (color = :red,), a_c = :blue),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'a_c' argument, \
         but it has already been specified \
         as 'color' within a 'apple' argument. \
         Consider removing either one.",
    )

    @argfails(
        nocontext(apple_color = :red, a_c = :blue),
        "Ambiguous or redundant specification in aliased 2D input for 'Mix': \
         'apple' value for 'color' is specified \
         as 'a_c' argument, \
         but it has already been specified \
         as 'apple_color' argument. \
         Consider removing either one.",
    )

    # Use additional semantic checks.
    @argfails(
        nocontext(apple_color = :red, berry_depth = 15),
        "Berry too deep for a red apple."
    )

    #---------------------------------------------------------------------------------------
    # Guard nested 2D api *devs* against possible ambiguous input.
    # (use random trigrams as api names to not have tests interact with each other)

    @aliasing_dict(SneakDict, "sneak", :sneak, (:ambiguous => [:a],))
    global tfi_types = nothing # (dummy)
    @failswith(
        @prepare_2D_api(Tfi, FruitDict, SneakDict),
        "Ambiguous aliasing for 'Tfi' 2D API: \
         argument 'a' either means 'fruit::apple' or 'sneak::ambiguous'."
    )
    global euz_types = nothing
    @failswith(
        @prepare_2D_api(Euz, SneakDict, FruitDict),
        "Ambiguous aliasing for 'Euz' 2D API: \
         argument 'a' either means 'sneak::ambiguous' or 'fruit::apple'."
    )

    @aliasing_dict(SneakDict, "sneak", :sneak, (:dummy => [:d], :alter_daemon => [:a_d]))
    global ycd_types = nothing # (dummy)
    @failswith(
        @prepare_2D_api(Ycd, FruitDict, SneakDict),
        "Ambiguous aliasing for 'Ycd' 2D API: \
         argument 'a_d' either means 'sneak::alter_daemon' \
         or 'sneak::dummy' within 'fruit::apple'."
    )
    global rig_types = nothing
    @failswith(
        @prepare_2D_api(Rig, SneakDict, FruitDict),
        "Ambiguous aliasing for 'Rig' 2D API: \
         argument 'a_d' either means 'sneak::alter_daemon' \
         or 'fruit::apple' within 'sneak::dummy'."
    )

    @aliasing_dict(SneakDict, "sneak", :sneak, (:dummy => [:d], :direct_attack => [:d_a]))
    global bbt_types = nothing
    @failswith(
        @prepare_2D_api(Bbt, FruitDict, SneakDict),
        "Ambiguous aliasing for 'Bbt' 2D API: \
         argument 'd_a' either means 'sneak::direct_attack' \
         or 'sneak::dummy' within 'fruit::apple'."
    )
    global daz_types = nothing
    @failswith(
        @prepare_2D_api(Daz, SneakDict, FruitDict),
        "Ambiguous aliasing for 'Daz' 2D API: \
         argument 'd_a' either means 'sneak::direct_attack' \
         or 'fruit::apple' within 'sneak::dummy'."
    )

end

end
