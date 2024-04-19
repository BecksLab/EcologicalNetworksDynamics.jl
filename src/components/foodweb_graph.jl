# Wrap a SimpleDiGraph into a custom type indexed by stable labels
# to represent either a foodweb or its biomass-foodweb restriction.

"""
Representation of a restriction of the graph model
to only species nodes and trophic edges.
Construct with the `.trophic_graph` property of the model.
"""
struct TrophicGraph
    graph::SimpleDiGraph
    labels::Dict{Symbol,Int} # {label -> node index}
    revmap::Vector{Symbol} # {node index -> label}
end

notaspecies(sp) = argerr("Not a species in the trophic graph: $(repr(sp)).")

"""
    remove_species!(g::TrophicGraph, sp)

Remove the species from the graph,
along with all corresponding edges.
"""
function remove_species!(g::TrophicGraph, sp)
    # Update labels maps on vertices removal.
    (; graph, labels, revmap) = g
    sp = Symbol(sp)
    sp in keys(labels) || notaspecies(sp)
    # This first swaps `i` with `n` then removes it.
    n = length(labels)
    i = pop!(labels, sp)
    rem_vertex!(graph, i) ||
        throw("Corrupted internal graph: this is a bug in the package.")
    if i != n
        last = revmap[n]
        labels[last] = i
        revmap[i] = pop!(revmap)
    else
        pop!(revmap)
    end
    nothing
end
export remove_species!

function trophic_graph(m::InnerParms)
    TrophicGraph(
        SimpleDiGraph(m._trophic_links),
        Dict(m._species_index),
        deepcopy(m._species_names),
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
n_species(g::TrophicGraph) = nv(g.graph)
export n_species

"""
    n_trophic_links(g::TrophicGraph)
"""
n_trophic_links(g::TrophicGraph) = ne(g.graph)
export n_trophic_links

"""
    species(g::TrophicGraph)

Iterate over nodes in the trophic graph.
"""
species(g::TrophicGraph) = Iterators.map(identity, g.revmap)
export species

"""
    trophic_links(g::TrophicGraph)

Iterate over edges in the trophic graph.
"""
function trophic_links(g::TrophicGraph)
    (; revmap) = g
    map(edges(g.graph)) do (i_source, i_target)
        revmap[i_source] => revmap[i_target]
    end
end
export trophic_links

"""
    has_species(g::TrophicGraph, sp)

Query trophic graph for the existence of the given trophic node.
"""
has_species(g::TrophicGraph, sp) = Symbol(sp) in g.labels
export has_species


"""
    has_trophic_link(g::TrophicGraph, predator, prey)

Query trophic graph for the existence of the given trophic edge.
"""
function has_trophic_link(g::TrophicGraph, predator, prey)
    (; labels) = g
    s, t = Symbol.((predator, prey))
    for k in (s, t)
        k in keys(labels) || notaspecies(k)
    end
    i_s, i_t = labels[s], labels[t]
    has_edge(g.graph, i_s, i_t)
end
export has_trophic_link

"""
    predators(g::TrophicGraph, sp)

Iterate over predators of the given species.
"""
function predators(g::TrophicGraph, sp)
    (; graph, labels, revmap) = g
    sp = Symbol(sp)
    sp in keys(labels) || notaspecies(sp)
    i_sp = labels[sp]
    Iterators.map(inneighbors(graph, i_sp)) do i_source
        revmap[i_source]
    end
end
export predators

"""
    preys(g::TrophicGraph, sp)

Iterate over preys of the given species.
"""
function preys(g::TrophicGraph, sp)
    (; graph, labels, revmap) = g
    sp = Symbol(sp)
    sp in keys(labels) || notaspecies(sp)
    i_sp = labels[sp]
    Iterators.map(outneighbors(graph, i_sp)) do i_target
        revmap[i_target]
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
