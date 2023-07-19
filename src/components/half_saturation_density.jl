# Set or generate half saturation densities for every consumer in the model.

# Adapted from maximum consumption rate.

# One blueprint variant, but keep the same pattern as other biorates
# just for consistency, in case of future pattern evolution.

# ==========================================================================================
abstract type HalfSaturationDensity <: ModelBlueprint end
# All subtypes must require(Foodweb).

HalfSaturationDensity(B0) = HalfSaturationDensityFromRawValues(B0)
export HalfSaturationDensity

#-------------------------------------------------------------------------------------------
mutable struct HalfSaturationDensityFromRawValues <: HalfSaturationDensity
    B0::@GraphData {Scalar, SparseVector, Map}{Float64}
    HalfSaturationDensityFromRawValues(B0) = new(@tographdata B0 SNK{Float64})
end

function F.check(model, bp::HalfSaturationDensityFromRawValues)
    (; _consumers_mask, _consumers_sparse_index) = model
    (; B0) = bp
    @check_refs_if_list B0 :consumers _consumers_sparse_index dense
    @check_template_if_sparse B0 _consumers_mask :consumers
end

function store_legacy_B0!(model, B0::SparseVector{Float64})
    model._scratch[:half_saturation_density] = collect(B0)
    model._cache[:half_saturation_density] = B0
end

function F.expand!(model, bp::HalfSaturationDensityFromRawValues)
    (; _consumers_mask, _species_index) = model
    (; B0) = bp
    @to_sparse_vector_if_map B0 _species_index
    @to_template_if_scalar Real B0 _consumers_mask
    store_legacy_B0!(model, B0)
end

@component HalfSaturationDensityFromRawValues requires(Foodweb)
export HalfSaturationDensityFromRawValues

#-------------------------------------------------------------------------------------------
# Keep in case more alternate blueprints are added.
# @conflicts(HalfSaturationDensityFromRawValues)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:HalfSaturationDensity}) = HalfSaturationDensity

# ==========================================================================================
@expose_data nodes begin
    property(half_saturation_density)
    get(HalfSaturationDensities{Float64}, sparse, "consumer")
    ref_cache(m -> nothing) # Cache loaded on component expansion.
    template(m -> m._consumers_mask)
    write!((m, rhs, i) -> (m._scratch[:half_saturation_density][i] = rhs))
    @species_index
    depends(HalfSaturationDensity)
end

# ==========================================================================================
display_short(bp::HalfSaturationDensity; kwargs...) =
    display_short(bp, HalfSaturationDensity; kwargs...)
display_long(bp::HalfSaturationDensity; kwargs...) =
    display_long(bp, HalfSaturationDensity; kwargs...)
F.display(model, ::Type{<:HalfSaturationDensity}) =
    "Half-saturation density: [$(join_elided(model._half_saturation_density, ", "))]"
