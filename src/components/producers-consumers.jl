# Two species categories defined from the foodweb:
# 'Producer' species are all non-sources of trophic links.
# 'Consumer species are all sources of trophic links.

#-------------------------------------------------------------------------------------------
# Spot species sub-compartments.

@expose_data nodes begin
    property(producers_mask)
    get(ProducersMask{Bool}, sparse, "species")
    ref_cache(m -> sparse([!any(row) for row in eachrow(m._trophic_links)]))
    @species_index
    depends(Foodweb)
end

@expose_data nodes begin
    property(consumers_mask)
    get(ConsumersMask{Bool}, sparse, "species")
    ref_cache(m -> sparse([any(row) for row in eachrow(m._trophic_links)]))
    @species_index
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Count either

@expose_data graph begin
    property(n_producers)
    get(m -> sum(m._producers_mask))
    depends(Foodweb)
end

@expose_data graph begin
    property(n_consumers)
    get(m -> sum(m._consumers_mask))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Query one particular index.

is_producer(m::InnerParms, i) = m.producers_mask[i]
is_consumer(m::InnerParms, i) = m.consumers_mask[i]
is_producer(m::InnerParms, i::Integer) = m._producers_mask[i]
is_consumer(m::InnerParms, i::Integer) = m._consumers_mask[i] # No need for the view/index.
@method is_producer depends(Foodweb)
@method is_consumer depends(Foodweb)
export is_producer, is_consumer

# Get corresponding species indices (iterator).
@expose_data graph begin
    property(producers_indices)
    get(m -> (i for (i, is_cons) in enumerate(m._producers_mask) if is_cons))
    depends(Foodweb)
end
@expose_data graph begin
    property(consumers_indices)
    get(m -> (i for (i, is_cons) in enumerate(m._consumers_mask) if is_cons))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Get corresponding (orderded) Symbol ↦ Integer indexes, in the space of species indices.

@expose_data graph begin
    property(producers_sparse_index)
    ref_cache(
        m -> OrderedDict(name => i for (name, i) in m._species_index if is_producer(m, i)),
    )
    get(m -> deepcopy(m._producers_sparse_index))
    depends(Foodweb)
end

@expose_data graph begin
    property(consumers_sparse_index)
    ref_cache(
        m -> OrderedDict(name => i for (name, i) in m._species_index if is_consumer(m, i)),
    )
    get(m -> deepcopy(m._consumers_sparse_index))
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Same, but within a new dedicated, compact indices space.

@expose_data graph begin
    property(producers_dense_index)
    ref_cache(
        m -> OrderedDict(
            name => i for (i, name) in enumerate(m.species_names[m.producers_mask])
        ),
    )
    get(m -> deepcopy(m._producers_dense_index))
    depends(Foodweb)
end

@expose_data graph begin
    property(consumers_dense_index)
    ref_cache(
        m -> OrderedDict(
            name => i for (i, name) in enumerate(m.species_names[m.consumers_mask])
        ),
    )
    get(m -> deepcopy(m._consumers_dense_index))
    depends(Foodweb)
end
