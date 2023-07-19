# Set or generate maximum consumption rates for every consumer in the model.

# Two blueprint variants "for the same component",
# depending on whether allometric rules are used.

# ==========================================================================================
abstract type MaximumConsumption <: ModelBlueprint end
# All subtypes must require(Foodweb).

function MaximumConsumption(y)

    @check_if_symbol y (:Miele2019,)

    if y == :Miele2019
        MaximumConsumptionFromAllometry(y)
    else
        MaximumConsumptionFromRawValues(y)
    end

end

export MaximumConsumption

#-------------------------------------------------------------------------------------------
mutable struct MaximumConsumptionFromRawValues <: MaximumConsumption
    y::@GraphData {Scalar, SparseVector, Map}{Float64}
    MaximumConsumptionFromRawValues(y) = new(@tographdata y SNK{Float64})
end

function F.check(model, bp::MaximumConsumptionFromRawValues)
    (; _consumers_mask, _consumers_sparse_index) = model
    (; y) = bp
    @check_refs_if_list y :consumers _consumers_sparse_index dense
    @check_template_if_sparse y _consumers_mask :consumers
end

function store_legacy_y!(model, y::SparseVector{Float64})
    model.biorates.y = collect(y)
    model._cache[:maximum_consumption] = y
end

function F.expand!(model, bp::MaximumConsumptionFromRawValues)
    (; _consumers_mask, _species_index) = model
    (; y) = bp
    @to_sparse_vector_if_map y _species_index
    @to_template_if_scalar Real y _consumers_mask
    store_legacy_y!(model, y)
end

@component MaximumConsumptionFromRawValues requires(Foodweb)
export MaximumConsumptionFromRawValues

#-------------------------------------------------------------------------------------------
miele2019_maximum_consumption_allometry_rates() =
    Allometry(; ectotherm = (a = 4, b = 0), invertebrate = (a = 8, b = 0))

mutable struct MaximumConsumptionFromAllometry <: MaximumConsumption
    allometry::Allometry
    MaximumConsumptionFromAllometry(; kwargs...) = new(parse_allometry_arguments(kwargs))
    MaximumConsumptionFromAllometry(allometry::Allometry) = new(allometry)
    function MaximumConsumptionFromAllometry(default::Symbol)
        @check_if_symbol default (:Miele2019,)
        return @build_from_symbol default (
            :Miele2019 => new(miele2019_maximum_consumption_allometry_rates())
        )
    end
end

F.buildsfrom(::MaximumConsumptionFromAllometry) = [BodyMass, MetabolicClass]

function F.check(_, bp::MaximumConsumptionFromAllometry)
    al = bp.allometry
    check_template(
        al,
        miele2019_maximum_consumption_allometry_rates(),
        "maximum consumption rate",
    )
end

function F.expand!(model, bp::MaximumConsumptionFromAllometry)
    (; _M, _metabolic_classes, _consumers_mask) = model
    y = sparse_nodes_allometry(bp.allometry, _consumers_mask, _M, _metabolic_classes)
    store_legacy_y!(model, y)
end

@component MaximumConsumptionFromAllometry requires(Foodweb)
export MaximumConsumptionFromAllometry

#-------------------------------------------------------------------------------------------
@conflicts(MaximumConsumptionFromRawValues, MaximumConsumptionFromAllometry,)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:MaximumConsumption}) = MaximumConsumption

# ==========================================================================================
@expose_data nodes begin
    property(maximum_consumption, y)
    get(MaximumConsumptionRates{Float64}, sparse, "consumer")
    ref_cache(m -> nothing) # Cache loaded on component expansion.
    template(m -> m._consumers_mask)
    write!((m, rhs, i) -> (m.biorates.y[i] = rhs))
    @species_index
    depends(MaximumConsumption)
end

# ==========================================================================================
display_short(bp::MaximumConsumption; kwargs...) =
    display_short(bp, MaximumConsumption; kwargs...)
display_long(bp::MaximumConsumption; kwargs...) =
    display_long(bp, MaximumConsumption; kwargs...)
F.display(model, ::Type{<:MaximumConsumption}) =
    "MaximumConsumption: [$(join_elided(model._maximum_consumption, ", "))]"
