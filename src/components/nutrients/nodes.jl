# Nutrients nodes compartments, akin to `Nodes`.
# Two possible blueprints because their number can be inferred from producer species.

# ==========================================================================================
# Call it 'Nodes' because the module is already named 'Nutrients'.
abstract type Nodes <: ModelBlueprint end
# Don't export, to encourage disambiguated access as `Nutrients.Nodes`.

Nodes(raw) =
    if raw isa Symbol
        NodesFromFoodweb(raw)
    else
        RawNodes(raw)
    end

# Akin to Species.
mutable struct RawNodes <: Nodes
    names::Vector{Symbol}
    RawNodes(names) = new(Symbol.(names))
    RawNodes(n::Integer) = new([Symbol(:n, i) for i in 1:n])
    RawNodes(names::Vector{Symbol}) = new(names)
end

function F.check(_, bp::RawNodes)
    (; names) = bp
    # Forbid duplicates (triangular check).
    for (i, a) in enumerate(names)
        for j in (i+1):length(names)
            b = names[j]
            a == b && checkfails("Nutrients $i and $j are both named $(repr(a)).")
        end
    end
end

function add_nutrients!(model, names)
    # Store in the scratch, and only alias to model.producer_growth
    # if the corresponding component is loaded.
    model._scratch[:nutrients_names] = names
    model._scratch[:nutrients_index] = OrderedDict(n => i for (i, n) in enumerate(names))
end

F.expand!(model, bp::Nodes) = add_nutrients!(model, bp.names)

@component RawNodes

#-------------------------------------------------------------------------------------------
mutable struct NodesFromFoodweb <: Nodes
    method::Symbol
    function NodesFromFoodweb(method)
        method = Symbol(method)
        @check_symbol method (:one_per_producer,)
        new(method)
    end
end

function F.early_check(_, bp::NodesFromFoodweb)
    (; method) = bp
    @check_symbol method (:one_per_producer,)
end

function F.expand!(model, bp::NodesFromFoodweb)
    (; method) = bp
    (; n_producers) = model
    names = @build_from_symbol(
        method,
        :one_per_producer => [Symbol(:n, i) for i in 1:n_producers],
    )
    add_nutrients!(model, names)
end

@component NodesFromFoodweb requires(Foodweb)

#-------------------------------------------------------------------------------------------
@conflicts(RawNodes, NodesFromFoodweb)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Nodes}) = Nodes

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
display_short(bp::Nodes; kwargs...) = display_short(bp, Nodes; kwargs...)
display_long(bp::Nodes; kwargs...) = display_long(bp, Nodes; kwargs...)
function F.display(model, ::Type{<:Nodes})
    N = model.n_nutrients
    names = model.nutrients_names
    "Nutrients: $N ($(join_elided(names, ", ")))"
end
