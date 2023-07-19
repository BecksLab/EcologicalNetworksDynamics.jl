# Two species categories defined from the foodweb:
# 'Prey' species are all targets of trophic links.
# 'Top' species are all non-targets of trophic links.

#-------------------------------------------------------------------------------------------
# Spot species sub-compartments.

@expose_data nodes begin
    property(preys_mask)
    get(PreysMask{Bool}, sparse, "species")
    ref_cache(m -> sparse([any(col) for col in eachcol(m._trophic_links)]))
    @species_index
    depends(Foodweb)
end

@expose_data nodes begin
    property(tops_mask)
    get(TopsMask{Bool}, sparse, "species")
    ref_cache(m -> sparse([!any(col) for col in eachcol(m._trophic_links)]))
    @species_index
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Count either

@expose_data graph begin
    property(n_preys)
    get(m -> sum(m._preys_mask))
    depends(Foodweb)
end

@expose_data graph begin
    property(n_tops)
    get(m -> sum(m._tops_mask))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Query one particular index.

is_prey(m::InnerParms, i) = m.preys_mask[i]
is_top(m::InnerParms, i) = m.tops_mask[i]
is_prey(m::InnerParms, i::Integer) = m._preys_mask[i]
is_top(m::InnerParms, i::Integer) = m._tops_mask[i] # No need for the view/index.
@method is_prey depends(Foodweb)
@method is_top depends(Foodweb)
export is_prey, is_top

# Get corresponding species indices (iterator).
@expose_data graph begin
    property(preys_indices)
    get(m -> (i for (i, is_cons) in enumerate(m._preys_mask) if is_cons))
    depends(Foodweb)
end
@expose_data graph begin
    property(tops_indices)
    get(m -> (i for (i, is_cons) in enumerate(m._tops_mask) if is_cons))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Get corresponding (orderded) Symbol ↦ Integer indexes, in the space of species indices.

@expose_data graph begin
    property(preys_sparse_index)
    ref_cache(
        m -> OrderedDict(name => i for (name, i) in m._species_index if is_prey(m, i)),
    )
    get(m -> deepcopy(m._preys_sparse_index))
    depends(Foodweb)
end

@expose_data graph begin
    property(tops_sparse_index)
    ref_cache(m -> OrderedDict(name => i for (name, i) in m._species_index if is_top(m, i)))
    get(m -> deepcopy(m._tops_sparse_index))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Same, but within a new dedicated, compact indices space.

@expose_data graph begin
    property(preys_dense_index)
    ref_cache(
        m -> OrderedDict(
            name => i for (i, name) in enumerate(m.species_names[m.preys_mask])
        ),
    )
    get(m -> deepcopy(m._preys_dense_index))
    depends(Foodweb)
end

@expose_data graph begin
    property(tops_dense_index)
    ref_cache(
        m ->
            OrderedDict(name => i for (i, name) in enumerate(m.species_names[m.tops_mask])),
    )
    get(m -> deepcopy(m._tops_dense_index))
    depends(Foodweb)
end
