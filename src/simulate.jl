# Major purpose of the whole model specification: simulate dynamics.
simulate(model, u0, _ownedcopy; kwargs...) =
    Internals.simulate(model, u0; _ownedcopy, kwargs...)
@method simulate depends(FunctionalResponse, ProducerGrowth, Metabolism, Mortality)
export simulate
# The actual exposed method freezes the model value at the point simulation started,
# so as to access it later.
simulate(model::Model, u0; kwargs...) = simulate(model, u0, copy(model); kwargs...)

# Retrieve the model as it was when simulation started.
const Solution = SciMLBase.AbstractODESolution
ref_model(sol::Solution) =
    try
        sol.prob.p.original_params
    catch
        argerr("Cannot retrieve the original ecological model from this solution value: \
                is it the result of $simulate(::$Model, ...)?")
    end
get_model(sol::Solution) = copy(ref_model(sol))
export get_model

# Query extinct species.
extinction_events(sol::Solution) =
    try
        sol.prob.p.extinct_sp
    catch
        argerr("Cannot retrieve extinction events from this solution value: \
                is it the result of $simulate(::$Model, ...)?")
    end

# By index.
function extinct_species_indices(sol::Solution)
    events = extinction_events(sol)
    # Order result by extinction event.
    OrderedDict(sort(collect(events); by = last)...)
end

# Same with species names instead.
function extinct_species(sol::Solution)
    names = ref_model(sol).species_names
    ext = extinct_species_indices(sol)
    OrderedDict(names[i] => time for (i, time) in ext)
end
export extinct_species

# Reverse: no extinction dates, but then the full index can be given.
function living_species(sol::Solution)
    (; _species_index) = ref_model(sol)
    events = extinction_events(sol)
    OrderedDict(n => i for (n, i) in _species_index if !haskey(events, i))
end
