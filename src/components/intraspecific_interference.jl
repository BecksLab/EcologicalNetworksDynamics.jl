# Set or generate intra-specific interference for every consumer in the model.

# Adapted from half saturation density.

# One blueprint variant, but keep the same pattern as other biorates
# just for consistency, in case of future pattern evolution.

# ==========================================================================================
abstract type IntraspecificInterference <: ModelBlueprint end
# All subtypes must require(Foodweb).

IntraspecificInterference(c) = IntraspecificInterferenceFromRawValues(c)
export IntraspecificInterference

#-------------------------------------------------------------------------------------------
mutable struct IntraspecificInterferenceFromRawValues <: IntraspecificInterference
    c::@GraphData {Scalar, SparseVector, Map}{Float64}
    IntraspecificInterferenceFromRawValues(c) = new(@tographdata c SNK{Float64})
end

function F.check(model, bp::IntraspecificInterferenceFromRawValues)
    (; _consumers_mask, _consumers_sparse_index) = model
    (; c) = bp
    @check_refs_if_list c :consumers _consumers_sparse_index dense
    @check_template_if_sparse c _consumers_mask :consumers
end

function store_legacy_c!(model, c::SparseVector{Float64})
    model._scratch[:intraspecific_interference] = collect(c)
    model._cache[:intraspecific_interference] = c
end

function F.expand!(model, bp::IntraspecificInterferenceFromRawValues)
    (; _consumers_mask, _species_index) = model
    (; c) = bp
    @to_sparse_vector_if_map c _species_index
    @to_template_if_scalar Real c _consumers_mask
    store_legacy_c!(model, c)
end

@component IntraspecificInterferenceFromRawValues requires(Foodweb)
export IntraspecificInterferenceFromRawValues

#-------------------------------------------------------------------------------------------
# Keep in case more alternate blueprints are added.
# @conflicts(IntraspecificInterferenceFromRawValues)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:IntraspecificInterference}) = IntraspecificInterference

# ==========================================================================================
@expose_data nodes begin
    property(intraspecific_interference)
    get(IntraspecificInterferences{Float64}, sparse, "consumer")
    ref_cache(m -> nothing) # Cache loaded on component expansion.
    template(m -> m._consumers_mask)
    write!((m, rhs, i) -> (m._scratch[:intraspecific_interference][i] = rhs))
    @species_index
    depends(IntraspecificInterference)
end

# ==========================================================================================
display_short(bp::IntraspecificInterference; kwargs...) =
    display_short(bp, IntraspecificInterference; kwargs...)
display_long(bp::IntraspecificInterference; kwargs...) =
    display_long(bp, IntraspecificInterference; kwargs...)
F.display(model, ::Type{<:IntraspecificInterference}) =
    "Intra-specific interference: [$(join_elided(model._intraspecific_interference, ", "))]"
