#=
Simulations of biomass dynamics
=#

function simulate(
    Parameters::ModelParameters,
    B0;
    start::Int64=0,
    stop::Int64=500,
    use::Symbol=:nonstiff,
    extinction_threshold::Float64=1e-6,
    interval_tkeep::Number=0.25
)

    # Tests and format
    S = richness(Parameters.FoodWeb)
    length(B0) ∈ [1, S] || throw(ArgumentError("B0 should be of length 1 or S
        (species richeness)."))
    length(B0) == S || (B0 = repeat([B0], S))
    start < stop || throw(ArgumentError("\"start\" should be smaller than \"stop\"."))
    use ∈ vec([:stiff :nonstiff]) || throw(ArgumentError("\"use\"use should be \"::stiff\"
        or \"::nonstiff\"."))
    alg = use == :stiff ? Rodas4(autodiff=false) : Tsit5()

    # Pre-allocate the timeseries matrix
    tspan = (float(start), float(stop))
    t_keep = collect(start:interval_tkeep:stop)

    # Perform the actual integration
    prob = ODEProblem(dBdt!, B0, tspan, Parameters)
    sol = solve(prob, alg, saveat=t_keep)

    # Output
    B_trajectory = hcat(sol.u...)'
    (ModelParameters=Parameters, t=sol.t, B=B_trajectory)
end
