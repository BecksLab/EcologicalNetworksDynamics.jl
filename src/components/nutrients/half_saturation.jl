# Set or generate half saturations for every producer-to-nutrient link in the model.
#
# Copied and adapted from concentrations.

# ==========================================================================================
abstract type HalfSaturation <: ModelBlueprint end
# All subtypes must require(Nutrients.Nodes,Foodweb).

HalfSaturation(h) = HalfSaturationFromRawValues(h)
export HalfSaturation

#-------------------------------------------------------------------------------------------
mutable struct HalfSaturationFromRawValues <: HalfSaturation
    h::@GraphData {Scalar, Matrix}{Float64}
    HalfSaturationFromRawValues(h) = new(@tographdata h SM{Float64})
end

F.can_imply(bp::HalfSaturationFromRawValues, ::Type{Nutrients.Nodes}) = !(bp.h isa Real)
Nutrients.Nodes(bp::HalfSaturationFromRawValues) = Nutrients.Nodes(size(bp.h, 2))

function F.check(model, bp::HalfSaturationFromRawValues)
    (; n_producers, n_nutrients) = model
    (; h) = bp
    @check_size_if_matrix h (n_producers, n_nutrients)
end

function F.expand!(model, bp::HalfSaturationFromRawValues)
    (; n_producers, n_nutrients) = model
    (; h) = bp
    @to_size_if_scalar Real h (n_producers, n_nutrients)
    model._scratch[:nutrients_half_saturation] = h
end

@component HalfSaturationFromRawValues requires(Foodweb) implies(Nutrients.Nodes)
export HalfSaturationFromRawValues

#-------------------------------------------------------------------------------------------
# Keep in case more alternate blueprints are added.
# @conflicts(HalfSaturationFromRawValues)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:HalfSaturation}) = HalfSaturation

# ==========================================================================================
@expose_data edges begin
    property(nutrients_half_saturation)
    get(HalfSaturations{Float64}, "producer-to-nutrient link")
    ref(m -> m._scratch[:nutrients_half_saturation])
    write!((m, rhs, i, j) -> (m._nutrients_half_saturation[i, j] = rhs))
    row_index(m -> m._producers_dense_index)
    col_index(m -> m._nutrients_index)
    depends(HalfSaturation)
end

# ==========================================================================================
display_short(bp::HalfSaturation; kwargs...) = display_short(bp, HalfSaturation; kwargs...)
display_long(bp::HalfSaturation; kwargs...) = display_long(bp, HalfSaturation; kwargs...)
function F.display(model, ::Type{<:HalfSaturation})
    h = model.nutrients_half_saturation
    min, max = minimum(h), maximum(h)
    "Nutrients half-saturation: " * if min == max
        "$min"
    else
        "ranging from $min to $max."
    end
end
