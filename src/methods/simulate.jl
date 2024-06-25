# The methods defined here depends on several components,
# which is the reason they live after all components specifications.

import SciMLBase: AbstractODESolution
const Solution = AbstractODESolution

# Major purpose of the whole model specification: simulate dynamics.
# TODO: This actual system method is useful to check required components
# but is is *not* the function exposed
# because a reference to the original model needs to be forwarded down to the internals
# to save a copy next to the results,
# and the @method macro misses the feature of providing this reference yet.
function _simulate(model::InnerParms, u0, tmax::Integer; kwargs...)
    # Depart from the legacy Internal defaults.
    @kwargs_helpers kwargs

    # No default simulation time anymore.
    given(:tmax) && argerr("Received two values for 'tmax': $tmax and $(take!(:tmax)).")

    # If set, produce an @info message
    # to warn user about possible degenerated network topologies.
    deg_top_arg = :display_degenerated_biomass_graph_properties
    deg_top = take_or!(deg_top_arg, true)

    # Lower threshold.
    extinction_threshold = take_or!(:extinction_threshold, 1e-12, Any)
    extinction_threshold = @tographdata extinction_threshold {Scalar, Vector}{Float64}

    # Shoo.
    verbose = take_or!(:verbose, false)

    # No TerminateSteadyState.
    extc = extinction_callback(model, extinction_threshold; verbose)
    callback = take_or!(:callbacks, Internals.CallbackSet(extc))

    out = Internals.simulate(
        model,
        u0;
        tmax,
        extinction_threshold,
        callback,
        verbose,
        kwargs...,
    )

    if deg_top
        # Analyze eventual topology.
        g = model.topology
        biomass = out[end]
        restrict_to_live_species!(g, biomass)
        diagnostics = []
        for comp in disconnected_components(g)
            sp = collect(live_species(g))
            prods = collect(live_producers(model, g))
            cons = collect(live_consumers(model, g))
            ip = isolated_producers(model, comp)
            sc = starving_consumers(model, comp)
            push!(diagnostics, (sp, prods, cons, ip, sc))
        end
        # HERE: display the message suggested in
        # https://github.com/BecksLab/EcologicalNetworksDynamics.jl/issues/151#issuecomment-2058641548
    end

    out
end
@method _simulate depends(FunctionalResponse, ProducerGrowth, Metabolism, Mortality)

# This exposed method does forward reference down to the internals..
simulate(model::Model, args...; kwargs...) = _simulate(model, args...; model, kwargs...)
# .. so that we *can* retrieve the original model from the simulation result.
get_model(sol::Solution) = copy(sol.prob.p.model) # (owned copy to not leak aliases)
export simulate, get_model


# Re-expose from internals so it works with the new API.
extinction_callback(m, thr; verbose = false) = Internals.ExtinctionCallback(thr, m, verbose)
export extinction_callback
@method extinction_callback depends(
    FunctionalResponse,
    ProducerGrowth,
    Metabolism,
    Mortality,
)
