"""
    restrict_to_live!(g::TrophicGraph, biomasses; threshold = 0)

Restrict the given graph to only nodes with "live" biomasses
*i.e.* biomasses above the given threshold.
"""
function restrict_to_live!(g::TrophicGraph, biomasses; threshold = 0)
    # Rely on species index memory to map biomass values to labels,
    # even though some species may already have been removed.
    no, nb = length.((original_species(g), biomasses))
    no, nb || argerr("The given trophic graph originally had $no species, \
                      but the given biomasses vector size is $nb.")
    for (sp, bm) in zip(original_species(g), biomasses)
        if bm > threshold
            has_species(g, sp) ||
                argerr("Species $(repr(sp)) has been removed from this trophic graph,
                       but it still has a biomass above threshold: $bm > $threshold.")
        else
            is_species_removed(g, sp) || remove_species!(g, sp)
        end
    end
end
export restrict_to_live!

"""
    disconnected_components(g::TrophicGraph)

Extract connected components from the trophic graph.
"""
function disconnected_components(g::TrophicGraph)
    # Split the 'full' graph `g` into 'sub'graphs corresponding to components.
    # Watch re-indexing.
    (; _topology, _labels, _revmap, _original_index) = g # Properties of the full graph.
    map(weakly_connected_components(_topology)) do component_nodes
        sub = SimpleDiGraph()
        reindex = Dict{Int,Int}() # { node index in full graph -> node index in sub graph }
        labels = Dict{Symbol,Int}()
        revmap = Vector{Symbol}()
        # Construct all nodes.
        for (i_sub, i_full) in enumerate(component_nodes)
            add_vertex!(sub)
            reindex[i_full] = i_sub
            sp = _revmap[i_full]
            push!(revmap, sp)
            labels[sp] = i_sub
        end
        # Construct all edges.
        for (sub_source, full_source) in enumerate(component_nodes)
            for full_target in neighbors(_topology, full_source)
                sub_target = reindex[full_target]
                add_edge!(sub, sub_source, sub_target)
            end
        end
        TrophicGraph(sub, labels, revmap, _original_index)
    end
end
export disconnected_components
