# Nutrients nodes compartments, akin to `Nodes`.

# Call it 'Nodes' because the module is already named 'Nutrients'.
mutable struct Nodes <: ModelBlueprint
    names::Vector{Symbol}
    Nodes(names) = new(Symbol.(names))
    Nodes(n::Integer) = new([Symbol(:n, i) for i in 1:n])
    Nodes(names::Vector{Symbol}) = new(names)
end

function F.check(_, bp::Nodes)
    (; names) = bp
    # Forbid duplicates (triangular check).
    for (i, a) in enumerate(names)
        for j in (i+1):length(names)
            b = names[j]
            a == b && checkfails("Nutrients $i and $j are both named $(repr(a)).")
        end
    end
end

function F.expand!(model, bp::Nodes)
    # Store in the scratch, and only alias to model.producer_growth
    # if the corresponding component is loaded.
    model._scratch[:nutrients_names] = bp.names
    model._scratch[:nutrients_index] = OrderedDict(n => i for (i, n) in enumerate(bp.names))
end

@component Nodes
# Don't export to encourage disambiguated access as `Nutrients.Nodes`.

# ==========================================================================================
@expose_data graph begin
    property(nutrients_richness, n_nutrients)
    get(m -> length(m._scratch[:nutrients_names]))
    depends(Nutrients.Nodes)
end

@expose_data nodes begin
    property(nutrients_names)
    get(NutrientsNames{Symbol}, "nutrient")
    ref(m -> m._scratch[:nutrients_names])
    depends(Nutrients.Nodes)
end

@expose_data graph begin
    property(nutrients_index)
    ref_cache(m -> m._scratch[:nutrients_index])
    get(m -> deepcopy(m._nutrients_index))
    depends(Nutrients.Nodes)
end

# ==========================================================================================
macro nutrients_index()
    esc(:(index(m -> m._nutrients_index)))
end

# ==========================================================================================
function F.display(model, ::Type{Nodes})
    N = model.n_nutrients
    names = model.nutrients_names
    "Nutrients: $N ($(join_elided(names, ", ")))"
end
