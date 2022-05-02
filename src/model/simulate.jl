#=
Simulations of biomass dynamics
=#

function simulate(
    params::ModelParameters,
    B0::AbstractVector;
    start::Number=0,
    stop::Number=500,
    use::Symbol=:nonstiff,
    extinction_threshold::AbstractFloat=1e-6,
    δt::Number=0.25
)

    # Check for consistency and format input arguments
    S = richness(params.network)
    length(B0) ∈ [1, S] || throw(ArgumentError("B0 of size $(length(B0)) instead of $S:
        B0 should be of length 1 or S (species richness)."))
    length(B0) == S || (B0 = repeat(B0, S))
    start < stop || throw(ArgumentError("'start' ($start) should be smaller than
        'stop' ($stop)."))
    use ∈ vec([:stiff :nonstiff]) || throw(ArgumentError("'use' should be '::stiff'
        or '::nonstiff'."))
    algorithm = use == :stiff ? Rodas4(autodiff=false) : Tsit5()

    # Define ODE problem and solve
    timespan = (float(start), float(stop))
    timesteps = collect(start:δt:stop)
    problem = ODEProblem(dBdt!, B0, timespan, params)
    solve(problem, algorithm, saveat=timesteps)
end
