#=
Simulations of biomass dynamics
=#

"""
    simulate(
        params,
        B0;
        t0=0,
        tmax=500,
        use=:nonstiff,
        extinction_threshold=1e-6,
        δt=0.25
    )

Run biomass dynamics simulation,
given model parameters (`params`) and the initial biomass (`B0`).

The dynamic is solved between t=`t0` and t=`tmax`.
However, if a steady state is found the simulation ends before `tmax`.
Biomass trajectories are saved every `δt`.

The output of this function is the result of `DifferentialEquations.solve()`,
to learn how to handle this output
see [Solution Handling](https://diffeq.sciml.ai/stable/basics/solution/).

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 0; 1 0]); # create foodweb

julia> params = ModelParameters(foodweb); # generate its parameters

julia> B0 = [0.5, 0.5]; # set initial biomass

julia> solution = simulate(params, B0); # run simulation

julia> solution.t[end] < 500 # true => a steady state has been found
true

julia> solution[begin] # initial biomass, recover B0
2-element Vector{Float64}:
 0.5
 0.5

julia> round.(solution[end], digits=2) # steady state biomass
2-element Vector{Float64}:
 0.19
 0.22
```
"""
function simulate(
    params::ModelParameters,
    B0::AbstractVector;
    t0::Number=0,
    tmax::Number=500,
    alg_hints::Symbol=:auto,
    extinction_threshold::AbstractFloat=1e-6,
    δt::Number=0.25
)

    # Check for consistency and format input arguments
    S = richness(params.network)
    length(B0) ∈ [1, S] || throw(ArgumentError("B0 of size $(length(B0)) instead of $S:
        B0 should be of length 1 or S (species richness)."))
    length(B0) == S || (B0 = repeat(B0, S))
    t0 < tmax || throw(ArgumentError("'t0' ($t0) should be smaller than
        'tmax' ($tmax)."))

    # Define callback - extinction threshold
    function species_under_threshold(u, t, integrator)
        any(0.0 .< u .< extinction_threshold)
    end
    function extinct_species!(integrator)
        integrator.u[integrator.u.<=extinction_threshold] .= 0.0
        extinct_sp = (1:length(integrator.u))[integrator.u.<=extinction_threshold]
        t = round(integrator.t, digits=2)
        println("$extinct_sp have gone extinct at time $t.")
    end
    extinction_callback = DiscreteCallback(species_under_threshold, extinct_species!)

    # Define callback - positive domain
    positive_domain = PositiveDomain()

    # Define callback - terminate at steady state
    terminate_steady_state = TerminateSteadyState(1e-5, 1e-3)

    callbacks = CallbackSet(extinction_callback, positive_domain, terminate_steady_state)

    # Define ODE problem and solve
    timespan = (float(t0), float(tmax))
    timesteps = collect(t0:δt:tmax)
    problem = ODEProblem(dBdt!, B0, timespan, params)
    solve(problem, saveat=timesteps, alg_hints=[alg_hints], callback=callbacks)
end

"""
    find_steady_state(params::ModelParameters, B0::AbstractVector)

Find a steady state of a system parametrized by a parameter set `params`
and some initial conditions `B0`.
The function returns a tuple (`steady_state`, `converged`).
If no steady state has been found `converged` is set to `false`
and `steady_state` to `nothing`.
Otherwise, `converged` is set to `true`
and `steady_state` to the corresponding value.
"""
function find_steady_state(
    params::ModelParameters,
    B0::AbstractVector;
    tmax=500,
    kwargs...
)
    out = simulate(params, B0; tmax=tmax, kwargs...)
    converged = has_terminated(out, tmax)
    steady_state = converged ? out.u[end] : nothing
    (steady_state=steady_state, converged=converged)
end

has_terminated(out, tmax) = out.t[end] < tmax
