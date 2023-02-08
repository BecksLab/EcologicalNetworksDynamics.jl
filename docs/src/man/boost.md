# Boosting simulations

```@setup econetd
using EcologicalNetworksDynamics
using Logging # TODO: remove once boost warnings are removed.
using Random
```

EcologicalNetworksDynamics helps you construct an ecological model
under the form of a [`ModelParameters`](@ref) value.
The major benefit of this value is that
it can automatically be translated into a set of "executable" ODEs.
Under the hood, this set of ODEs is implemented as a function
able to calculate, for every time step,
the temporal derivative of the biomass vector
``\frac{\mathrm{d}B}{\mathrm{d}t}``.
The function is named `EcologicalNetworksDynamics.dBdt!`,
but you are not supposed to call it directly.
Instead, you call [`simulate`](@ref)
which essentially parametrizes `EcologicalNetworksDynamics.dBdt!` correctly
and hands it to the ODE solver for you.

Your ecological model can take various different forms
(number of species variables, mortality,
[functional response](@ref functional_response),
[(non-)trophic interaction layers](@ref multiplex),
*etc.*).
As a consequence, `EcologicalNetworksDynamics.dBdt!` needs to be very flexible
to support all these possible features.
This comes at the cost of a heavy performance burden,
that needs to be carried on every time step during the simulation.

However, once your `model` has been created, for example with:

```@example econetd
foodweb = FoodWeb([
    0 0 0 0
    0 0 1 0
    1 0 0 0
    0 1 0 0
])
model = ModelParameters(foodweb; functional_response = BioenergeticResponse(foodweb))
B0 = [0.5, 0.5, 0.5, 0.5]
nothing # hide
```

Then it is likely that its parameters,
or number of layers, or species variables *etc.*
will *not* change throughout the simulation.
As a consequence, the performance penalty is unfair:
you pay for more flexibility than you actually need.

There is no direct way around this:
`EcologicalNetworksDynamics.dBdt!` needs to be flexible
because we (as developers) do not know what your model will look like,
but you (as a user) do not need this flexibility
for your particular `model` variable
since it is *fixed* for the time of simulation.

To address this problem, `EcologicalNetworksDynamics`
leverages the powerful Julia
[metaprogramming](https://docs.julialang.org/en/v1/manual/metaprogramming/)
facilities and makes it possible to generate,
given one `model` value,
one customized, performant `dBdt!` function dedicated to your very situation
(and not flexible at all).
This can speed up your simulations by large factors
like `x2` or `x10`, and even up to `x100`
depending on your model and your machine.
To make use of it, instead of using the regular:

```@example econetd
GC.gc() # hide
Logging.with_logger(Logging.NullLogger()) do # hide

@time trajectory = simulate(model, B0; tmax = 4e5)

nothing # hide
end #hide
```

You would use the following three-steps process:

```@example econetd
GC.gc() # hide
xp, data, dBdt! = nothing, nothing, nothing # hide
Logging.with_logger(Logging.NullLogger()) do # hide

@time xp, data = generate_dbdt(model, :raw)  # Generate dBdt! expression and associated data.
@time dBdt! = eval(xp)  # Evaluate into an actual function.
@time trajectory = simulate(model, B0; tmax = 4e5, diff_code_data = (dBdt!, data)) # Give this specialized function to `simulate()`.

global xp, data, dBdt! = xp, data, dBdt! # hide
end #hide
nothing # hide
```

Note that it's even faster once Julia has got rid
of the initial `dBdt!` compilation time.

```@example econetd
GC.gc() # hide
B1 = B0 .+ 0.1
Logging.with_logger(Logging.NullLogger()) do # hide
@time trajectory = simulate(model, B1; tmax = 4e5, diff_code_data = (dBdt!, data))

end #hide
nothing # hide
```

In the first step, [`generate_dbdt`](@ref)
translates your model into a dedicated Julia
[expression](https://docs.julialang.org/en/v1/manual/metaprogramming/#Expressions-and-evaluation).
In the second step, you
[`eval`](https://docs.julialang.org/en/v1/base/base/#Core.eval)uate
this expression into an actual function
that [`simulate`](@ref) can handle
instead of the default one `EcologicalNetworksDynamics.dBdt!`.
The generated expression can be inspected with the following:

```@example econetd
print(xp)
```

The generated expression is pretty grim
because it has been tailored for maximum performance
with your given `model`.
But you can see how every species and every interaction
has its dedicated line within it.

When the number of species and interactions become large
(like `S >≈ 20`)
the generated expression becomes large as well.
It eventually becomes so large
(like
[`SyntaxTree`](https://github.com/chakravala/SyntaxTree.jl)`.callcount(xp) >≈ 20,000`)
that the time it takes for Julia to compile it
actually overcomes the speedup gain
(but see
[Julia 1.9](https://discourse.julialang.org/t/profiling-compilation-of-a-large-generated-expression/83179?u=iago-lito)?).

In this situation, instead of asking for `:raw` code generation,
you may ask for `:compact` generation instead:

```@example econetd
Random.seed!(1) # hide

# Define model with numerous species and interactions.
S = 100
foodweb = FoodWeb(nichemodel, S; C = 0.04)
model = ModelParameters(foodweb; functional_response = BioenergeticResponse(foodweb))
B0 = repeat([0.5], S)

println("Run with generic code..")
GC.gc() # hide
Logging.with_logger(Logging.NullLogger()) do # hide
@time trajectory = simulate(model, B0; tmax = 2e5)
end # hide
xp, data, dBdt! = nothing, nothing, nothing # hide
GC.gc() # hide
Logging.with_logger(Logging.NullLogger()) do # hide

println("Run with :compact generated code, because :raw would be too long to compile.")
@time xp, data = generate_dbdt(model, :compact)  # (and not :raw)
@time dBdt! = eval(xp)  # Same procedure otherwise.
@time trajectory = simulate(model, B0; tmax = 2e5, diff_code_data = (dBdt!, data))

global xp, data, dBdt! = xp, data, dBdt! # hide
nothing # hide
end # hide
```

And once you have got rid of the initial `dBdt!` compilation time:

```@example econetd
GC.gc() # hide
B1 = B0 .+ 0.1
Logging.with_logger(Logging.NullLogger()) do # hide
@time trajectory = simulate(model, B1; tmax = 2e5, diff_code_data = (dBdt!, data))

end # hide
nothing # hide
```

In this situation, the generated expression looks a bit different:

```@example econetd
print(xp)
```

The `:compact` generated expression seems long,
but its size is fixed so it does not become larger
when `S` or the number of species interactions increases.
As a consequence, it can scale with the largest models
while keeping the satisfying performances.

As a rule of thumb,
and if you need to speed up the simulations,
use `:raw` whenever possible
but resort to `:compact` generated expressions
when `S >≈ 20`
or when your boosted `:raw` simulation
otherwise takes too much time to compile.

!!! warning
    
    Boosted simulations (involving
    [`generate_dbdt`](@ref),
    [`eval`](https://docs.julialang.org/en/v1/base/base/#Core.eval)
    and [`simulate`](@ref))
    are supposed to yield the same results
    as non-boosted simulations (using only [`simulate`](@ref)).
    This has been verified on small simulations
    while testing this package,
    but not on a very diverse, large set of simulations that would span
    all the features available in `EcologicalNetworksDynamics` yet.
    For this reason,
    a warning is printed whenever you use [`generate_dbdt`](@ref) for now,
    to explain why you should be careful.
    This warning will be removed once
    [#92](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues/92)
    has been adressed.

!!! warning
    
    Every new package feature modifying the eventual ODEs system
    needs to be implemented once in the regular simulator,
    then once in `:raw` and once in `:compact` boosted expressions generators.
    Implementing efficient `:raw` and `:compact` version is not always trivial.
    As a consequence, some features available today in regular simulation
    (like producers competition and [Non-Trophic Interactions](@ref multiplex))
    cannot yet be "boosted"
    ([#82](https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues/82)).
