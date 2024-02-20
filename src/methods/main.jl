# The methods defined here depends on several components,
# which is the reason they live after all components specifications.

# Major purpose of the whole model specification: simulate dynamics.
function simulate(model::InnerParms, u0, tmax::Integer; kwargs...)
    # Depart from the legacy Internal defaults.
    @kwargs_helpers kwargs

    # No default simulation time anymore.
    given(:tmax) && argerr("Received two values for 'tmax': $tmax and $(take!(:tmax)).")

    # Lower threshold.
    extinction_threshold = take_or!(:extinction_threshold, 1e-12, Any)
    extinction_threshold = @tographdata extinction_threshold {Scalar, Vector}{Float64}

    # Shoo.
    verbose = take_or!(:verbose, false)

    # No TerminateSteadyState.
    extc = extinction_callback(model, extinction_threshold; verbose)
    callback = take_or!(:callbacks, Internals.CallbackSet(extc))

    Internals.simulate(model, u0; tmax, extinction_threshold, callback, verbose, kwargs...)
end
@method simulate depends(FunctionalResponse, ProducerGrowth, Metabolism, Mortality)
export simulate

# Re-expose from internals so it works with the new API.
extinction_callback(m, thr; verbose = false) = Internals.ExtinctionCallback(thr, m, verbose)
export extinction_callback
@method extinction_callback depends(
    FunctionalResponse,
    ProducerGrowth,
    Metabolism,
    Mortality,
)
