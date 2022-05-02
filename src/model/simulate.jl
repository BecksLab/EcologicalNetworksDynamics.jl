#=
Simulations of biomass dynamics
=#

function simulate(
    params::ModelParameters,
    B0;
    start::Int64=0,
    stop::Int64=500,
    use::Symbol=:nonstiff,
    extinction_threshold::Float64=1e-6,
    δt::Number=0.25
)

    # Tests and format
    S = richness(params.network)
    length(B0) ∈ [1, S] || throw(ArgumentError("B0 should be of length 1 or S
        (species richeness)."))
    length(B0) == S || (B0 = repeat([B0], S))
    start < stop || throw(ArgumentError("'start' should be smaller than 'stop'."))
    use ∈ vec([:stiff :nonstiff]) || throw(ArgumentError("'use'use should be '::stiff'
        or '::nonstiff'."))
    algorithm = use == :stiff ? Rodas4(autodiff=false) : Tsit5()

    # Pre-allocate the timeseries matrix
    timespan = (float(start), float(stop))
    timesteps = collect(start:δt:stop)

    # Perform the actual integration
    problem = ODEProblem(dBdt!, B0, timespan, params)
    sol = solve(problem, algorithm, saveat=timesteps)

    # Output
    B_trajectory = hcat(sol.u...)'
    (ModelParameters=params, t=sol.t, B=B_trajectory)
end
