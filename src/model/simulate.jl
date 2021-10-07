#=
Simulations of biomass dynamics
=#

function simulate(MP::ModelParameters, biomass; start::Int64=0, stop::Int64=500, use::Symbol=:nonstiff, extinction_threshold::Float64=1e-6, interval_tkeep::Number=0.25)
    @assert stop > start
    @assert length(biomass) == richness(MP.FoodWeb)
  
    @assert use ∈ vec([:stiff :nonstiff])
    alg = use == :stiff ? Rodas4(autodiff=false) : Tsit5()
  
    S = richness(MP.FoodWeb)
  
    # Pre-allocate the timeseries matrix
    tspan = (float(start), float(stop))
    t_keep = collect(start:interval_tkeep:stop)
  
    # Perform the actual integration
    prob = ODEProblem(dBdt!, biomass, tspan, MP)
    
    sol = solve(prob, alg, saveat = t_keep)
  
    B = hcat(sol.u...)'
  
    output = (
        ModelParameters = MP,
        t = sol.t,
        B = B
    )
  
    return output
  
  end