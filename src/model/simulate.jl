#### Run biomass simulations ####
"""
    simulate(
        params::ModelParameters,
        B0::AbstractVector;
        t0::Number=0,
        tmax::Number=500,
        δt::Number=0.25,
        extinction_threshold=1e-6,
        verbose=true,
        callback=CallbackSet(
            PositiveDomain(),
            TerminateSteadyState(1e-5, 1e-3),
            ExtinctionCallback(extinction_threshold, verbose)
        ),
        kwargs...
    )

Run biomass dynamics simulation,
given model parameters (`params`) and the initial biomass (`B0`).

The dynamic is solved between t=`t0` and t=`tmax` (at worst) and
biomass are saved (at least) every `δt`.

By default, we give the following callbacks to `solve()`:

    - PositiveDomain (DiffEqCallbacks) ensures that biomass stays positive
    - TerminateSteadyState (DiffEqCallbacks) ends simulation if a steady state is found
    - ExtinguishSpecies (custom) extinguish species whose biomass goes under the
        `extinction_threshold`

You are free to provide other callbacks, either by changing the parameter values of the
callbacks above, choosing other callbacks from DiffEqCallbacks or by creating you own
callbacks.

Thanks to the extra keywords arguments `kwargs...`,
you have a direct access to the interface of solve.
Thus you can directly specify keyword arguments of solve(),
for instance if you want to hint toward stiff solver
you can give as an argument to simulate `alg_hints=[:stiff]`.

The output of this function is the result of `DifferentialEquations.solve()`,
to learn how to handle this output
see [Solution Handling](https://diffeq.sciml.ai/stable/basics/solution/).

If you are not interested in the biomass trajectories,
but want to find directly the biomass at steady state see [`find_steady_state`](@ref).

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]); # create the foodweb

julia> params = ModelParameters(foodweb); # generate the parameters

julia> B0 = [0.5, 0.5]; # set initial biomass

julia> solution = simulate(params, B0); # run simulation

julia> solution.retcode # => a steady state has been found
:Terminated

julia> solution[begin] == B0 # initial biomass equals initial biomass
true

julia> round.(solution[end], digits=2) # steady state biomass
2-element Vector{Float64}:
 0.19
 0.22
```

By default, the extinction callback throw a message when a species goes extinct.

```julia
julia> foodweb = FoodWeb([0 0; 1 0]);

julia> params = ModelParameters(foodweb);

julia> simulate(params, [0.5, 1e-12], verbose=true); # default: a message is thrown
[ Info: Species [2] is exinct. t=0.12316364776188903

julia> simulate(params, [0.5, 1e-12], verbose=true); # no message thrown
```
"""
function simulate(
    params::ModelParameters,
    B0::AbstractVector;
    t0::Number = 0,
    tmax::Number = 500,
    δt::Number = 0.25,
    extinction_threshold = 1e-5,
    verbose = true,
    callback = CallbackSet(
        PositiveDomain(),
        TerminateSteadyState(1e-6, 1e-4),
        ExtinguishSpecies(extinction_threshold, verbose),
    ),
    kwargs...,
)

    # Check for consistency and format input arguments
    S = richness(params.network)
    length(B0) == 1 && (B0 = repeat(B0, S))
    @check_equal_richness length(B0) S
    @check_lower_than t0 tmax

    # Define ODE problem and solve
    timespan = (t0, tmax)
    timesteps = collect(t0:δt:tmax)
    problem = ODEProblem(dBdt!, B0, timespan, params)
    solve(problem; saveat = timesteps, callback = callback, kwargs...)
end
#### end ####

#### Species extinction callback ####
"Callback to extinguish species under the `extinction_threshold`."
function ExtinguishSpecies(extinction_threshold::Number, verbose::Bool)

    # Condition to trigger the callback: a species biomass goes below the threshold.
    species_under_threshold(u, t, integrator) = any(u[u.>0] .< extinction_threshold)

    # Effect of the callback: the species biomass below the threshold are set to 0.
    function extinguish_species!(integrator)
        integrator.u[integrator.u.<=extinction_threshold] .= 0.0
        extinct_sp = (1:length(integrator.u))[integrator.u.<=extinction_threshold]
        t = integrator.t
        is_or_are = length(extinct_sp) > 1 ? "are" : "is"
        if verbose
            @info "Species $extinct_sp " * is_or_are * " exinct. t=$t"
        end
    end

    DiscreteCallback(species_under_threshold, extinguish_species!)
end

function ExtinguishSpecies(extinction_threshold::AbstractVector, verbose::Bool)

    # Condition to trigger the callback: a species biomass goes below the threshold.
    species_under_threshold(u, t, integrator) = any(u[u.>0] .< extinction_threshold[u.>0])

    # Effect of the callback: the species biomass below the threshold are set to 0.
    function extinguish_species!(integrator)
        integrator.u[integrator.u.<=extinction_threshold] .= 0.0
        extinct_sp = (1:length(integrator.u))[integrator.u.<=extinction_threshold]
        t = integrator.t
        is_or_are = length(extinct_sp) > 1 ? "are" : "is"
        if verbose
            @info "Species $extinct_sp " * is_or_are * " exinct. t=$t"
        end
    end

    DiscreteCallback(species_under_threshold, extinguish_species!)
end
#### end ####

#### Find steady state ####
"""
    find_steady_state(params::ModelParameters, B0::AbstractVector; kwargs...)

Find a steady state of a system parametrized by a parameter set `params`
and some initial conditions `B0`.
The function returns a tuple (`steady_state`, `terminated`).
If no steady state has been found `terminated` is set to `false`
and `steady_state` to `nothing`.
Otherwise, `terminated` is set to `true`
and `steady_state` to the corresponding value.

If you are not only interested in the steady state biomass,
but also in the trajectories see [`simulate`](@ref).

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]); # create the foodweb

julia> params = ModelParameters(foodweb); # generate the parameters

julia> B0 = [0.5, 0.5]; # set initial biomass

julia> solution = find_steady_state(params, B0);

julia> solution.terminated # => a steady state has been found
true

julia> round.(solution.steady_state, digits=2) # steady state biomass
2-element Vector{Float64}:
 0.19
 0.22
```
"""
function find_steady_state(params::ModelParameters, B0::AbstractVector; kwargs...)
    solution = simulate(params, B0; kwargs...)
    terminated = has_terminated(solution)
    steady_state = terminated ? solution.u[end] : nothing
    (steady_state = steady_state, terminated = terminated)
end

has_terminated(solution) = solution.retcode == :Terminated
#### end ####
