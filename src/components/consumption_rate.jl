# Set or generate consumption rates for every consumer in the model.

# Adapted from half saturation density.

# One blueprint variant, but keep the same pattern as other biorates
# just for consistency, in case of future pattern evolution.

# ==========================================================================================
abstract type ConsumptionRate <: ModelBlueprint end
# All subtypes must require(Foodweb).

ConsumptionRate(alpha) = ConsumptionRateFromRawValues(alpha)
export ConsumptionRate

#-------------------------------------------------------------------------------------------
mutable struct ConsumptionRateFromRawValues <: ConsumptionRate
    alpha::@GraphData {Scalar, SparseVector, Map}{Float64}
    ConsumptionRateFromRawValues(alpha) = new(@tographdata alpha SNK{Float64})
end

function F.check(model, bp::ConsumptionRateFromRawValues)
    (; _consumers_mask, _consumers_sparse_index) = model
    (; alpha) = bp
    @check_refs_if_list alpha :consumers _consumers_sparse_index dense
    @check_template_if_sparse alpha _consumers_mask :consumers
end

function F.expand!(model, bp::ConsumptionRateFromRawValues)
    (; _consumers_mask, _species_index) = model
    (; alpha) = bp
    @to_sparse_vector_if_map alpha _species_index
    @to_template_if_scalar Real alpha _consumers_mask
    model._scratch[:consumption_rate] = collect(alpha)
end

@component ConsumptionRateFromRawValues requires(Foodweb)
export ConsumptionRateFromRawValues

#-------------------------------------------------------------------------------------------
# Keep in case more alternate blueprints are added.
# @conflicts(ConsumptionRateFromRawValues)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:ConsumptionRate}) = ConsumptionRate

# ==========================================================================================
@expose_data nodes begin
    property(consumption_rate, alpha)
    get(ConsumptionRates{Float64}, sparse, "consumer")
    ref(m -> m._scratch[:consumption_rate])
    template(m -> m._consumers_mask)
    write!((m, rhs, i) -> (m._consumption_rate[i] = rhs))
    @species_index
    depends(ConsumptionRate)
end

# ==========================================================================================
display_short(bp::ConsumptionRate; kwargs...) =
    display_short(bp, ConsumptionRate; kwargs...)
display_long(bp::ConsumptionRate; kwargs...) = display_long(bp, ConsumptionRate; kwargs...)
F.display(model, ::Type{<:ConsumptionRate}) =
    "Consumption rate: [$(join_elided(model._consumption_rate, ", "))]"
