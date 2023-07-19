# The methods defined here depends on several components,
# which is the reason they live after all components specifications.

# Major purpose of the whole model specification: simulate dynamics.
simulate(model, u0; kwargs...) = Internals.simulate(model, u0; kwargs...)
@method simulate depends(FunctionalResponse, ProducerGrowth, Metabolism, Mortality)
export simulate

# Re-expose from internals so it works with the new API.
extinction_callback(m, thr; verbose=false) = Internals.ExtinctionCallback(thr, m, verbose)
@method extinction_callback depends(FunctionalResponse, ProducerGrowth, Metabolism, Mortality)
export extinction_callback
