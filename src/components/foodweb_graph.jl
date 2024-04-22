# Wrap a SimpleDiGraph into a custom type indexed by stable labels
# to represent either a foodweb or its biomass-foodweb restriction.
# HERE: rather a whole model graph with all nodes/edges layers,
#       and make this only a view into it.

"""
Representation of a restriction of the graph model
to only species nodes and trophic edges.
Construct with the `.trophic_graph` property of the model.
Once constructed, and even if some species are removed,
the trophic graph always remembers its original species index,
and their 'consumer' vs. 'producer' statuses.
This is useful to match it against biomass vectors even after species extinctions.
"""
struct TrophicGraph
    # Opaque type.
    _topology::SimpleDiGraph
    _labels::Dict{Symbol,Int} # {label -> node index}
    _revmap::Vector{Symbol} # {node index -> label}
    # Original species information.
    #   { original species index / label -> is_producer }
    _original_species::OrderedDict{Symbol,Bool}
end

function missing_label(g::TrophicGraph, sp)
    haskey(g._original_species, sp) &&
        argerr("Species $(repr(sp)) has been removed from this trophic graph.")
    argerr("Not a species in the trophic graph: $(repr(sp)).")
end

"""
    remove_species!(g::TrophicGraph, sp)

Remove the species from the graph,
along with all corresponding edges.
"""
function remove_species!(g::TrophicGraph, sp)
    # Update labels maps on vertices removal.
    (; _topology, _labels, _revmap) = g
    sp = Symbol(sp)
    haskey(_labels, sp) || missing_label(g, sp)
    # This first swaps `i` with `n` then removes it.
    n = length(_labels)
    i = pop!(_labels, sp)
    rem_vertex!(_topology, i) ||
        throw("Corrupted internal graph: this is a bug in the package.")
    if i != n
        last = _revmap[n]
        _labels[last] = i
        _revmap[i] = pop!(_revmap)
    else
        pop!(_revmap)
    end
    g
end
export remove_species!

function trophic_graph(m::InnerParms)
    TrophicGraph(
        SimpleDiGraph(m._trophic_links),
        Dict(m._species_index),
        m.species_names, # Need a fresh copy to update on removals.
        OrderedDict(
            n => is_producer for
            (n, is_producer) in zip(m._species_names, m._producers_mask)
        ),
    )
end

@expose_data graph begin
    property(trophic_graph, foodweb_graph)
    ref_cache(trophic_graph)
    get(m -> deepcopy(m._trophic_graph))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Mimick the AbstractGraph API but only expose labels.

"""
    n_species(g::TrophicGraph)
"""
n_species(g::TrophicGraph) = nv(g._topology)
export n_species

"""
    n_trophic_links(g::TrophicGraph)
"""
n_trophic_links(g::TrophicGraph) = ne(g._topology)
export n_trophic_links

"""
    species(g::TrophicGraph)

Iterate over nodes in the trophic graph.
"""
species(g::TrophicGraph) = Iterators.map(identity, g._revmap)
export species

"""
    original_species(g::TrophicGraph)

Iterate over species originally in the trophic graph, in their original order.
"""
original_species(g::TrophicGraph) = keys(g._original_species)
export original_species

"""
    trophic_links(g::TrophicGraph)

Iterate over edges in the trophic graph.
"""
function trophic_links(g::TrophicGraph)
    (; _revmap) = g
    map(edges(g._topology)) do (i_source, i_target)
        _revmap[i_source] => _revmap[i_target]
    end
end
export trophic_links

"""
    has_species(g::TrophicGraph, sp)

Query trophic graph for the existence of the given trophic node.
"""
has_species(g::TrophicGraph, sp) = haskey(g._labels, Symbol(sp))
export has_species

"""
    is_species_removed(g::TrophicGraph, sp)

Was this species originally part of this trophic graph and then later removed?
"""
function is_species_removed(g::TrophicGraph, sp)
    sp = Symbol(sp)
    haskey(g._original_species, sp) && !(haskey(g._labels, sp))
end
export is_species_removed

"""
    has_trophic_link(g::TrophicGraph, predator, prey)

Query trophic graph for the existence of the given trophic edge.
"""
function has_trophic_link(g::TrophicGraph, predator, prey)
    (; _labels) = g
    s, t = Symbol.((predator, prey))
    for k in (s, t)
        haskey(_labels, k) || missing_label(g, k)
    end
    i_s, i_t = _labels[s], _labels[t]
    has_edge(g._topology, i_s, i_t)
end
export has_trophic_link

"""
    predators(g::TrophicGraph, sp)

Iterate over predators of the given species.
"""
function predators(g::TrophicGraph, sp)
    (; _topology, _labels, _revmap) = g
    sp = Symbol(sp)
    haskey(_labels, sp) || missing_label(g, sp)
    i_sp = _labels[sp]
    Iterators.map(inneighbors(_topology, i_sp)) do i_source
        _revmap[i_source]
    end
end
export predators

"""
    preys(g::TrophicGraph, sp)

Iterate over preys of the given species.
"""
function preys(g::TrophicGraph, sp)
    (; _topology, _labels, _revmap) = g
    sp = Symbol(sp)
    haskey(_labels, sp) || missing_label(g, sp)
    i_sp = _labels[sp]
    Iterators.map(outneighbors(_topology, i_sp)) do i_target
        _revmap[i_target]
    end
end
export preys

#-------------------------------------------------------------------------------------------
# Display.

function Base.show(io::IO, g::TrophicGraph)
    nv, ne = n_species(g), n_trophic_links(g)
    s = ne > 1 ? "s" : ""
    print(io, "$TrophicGraph($(nv) species, $(ne) trophic link$s)")
end

function Base.show(io::IO, ::MIME"text/plain", g::TrophicGraph)
    print(io, "$TrophicGraph:")
    for sp in species(g)
        print(io, "\n  $(repr(sp)) => [")
        for (i_prey, prey) in enumerate(preys(g, sp))
            if i_prey > 1
                print(io, ", ")
            end
            print(io, repr(prey))
        end
        print(io, ']')
    end
end
