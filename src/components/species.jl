# Species nodes are the first basic type of node in the ecological graph model.
# On component expansion, they are given an index and a name,
# which cannot be changed later, or the number of species,
# because too many things depend on these.

mutable struct Species <: ModelBlueprint
    names::Vector{Symbol}
    # Generate dummy names if not provided.
    # Don't own data if useful to user.
    Species(names) = new(Symbol.(names))
    Species(n::Integer) = new([Symbol(:s, i) for i in 1:n])
    Species(names::Vector{Symbol}) = new(names)
end

function F.check(model, bp::Species)
    (; names) = bp
    # Forbid duplicates (triangular check).
    for (i, a) in enumerate(names)
        for j in (i+1):length(names)
            b = names[j]
            a == b && checkfails("Species $i and $j are both named $(repr(a)).")
        end
    end
end

function F.expand!(model, bp::Species)
    # Species are still internally stored within a value named "Foodweb",
    # but this will be refactored.
    fw = Internals.FoodWeb(bp.names)
    model.network = fw
    # Keep reference safe in case we later switch to a multiplex network,
    # and want to add the layers one by one.
    model._foodweb = fw
end

@component Species
export Species

# ==========================================================================================
# Basic queries

# Number of species aka. "richness".
@expose_data graph begin
    property(richness, species_richness, n_species, S)
    get(m -> length(m._species_index))
    depends(Species)
end

# View into species names.
@expose_data nodes begin
    property(species_names)
    get(SpeciesNames{Symbol}, "species")
    # Need to convert from internal legacy strings.
    ref_cache(m -> Symbol.(m._foodweb.species))
    depends(Species)
end

# Get (ordered) species index.
@expose_data graph begin
    property(species_index)
    ref_cache(m -> OrderedDict(name => i for (i, name) in enumerate(m._species_names)))
    get(m -> deepcopy(m._species_index))
    depends(Species)
end

# ==========================================================================================
# Numerous views into species nodes will make use of this index.
macro species_index()
    esc(:(index(m -> m._species_index)))
end

# ==========================================================================================
# Display.

function F.display(model, ::Type{Species})
    (; S) = model
    names = model.species_names
    "Species: $S ($(join_elided(names, ", ")))"
end
