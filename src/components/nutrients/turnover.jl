# Set or generate turnover rates for every nutrients in the model.
#
# One blueprint variant, but keep the same pattern as other biorates
# just for consistency, in case of future pattern evolution.

# ==========================================================================================
abstract type Turnover <: ModelBlueprint end
# All subtypes must require(Nutrients.Nodes).

Turnover(t) = TurnoverFromRawValues(t)
export Turnover

#-------------------------------------------------------------------------------------------
mutable struct TurnoverFromRawValues <: Turnover
    t::@GraphData {Scalar, Vector, Map}{Float64}
    TurnoverFromRawValues(t) = new(@tographdata t SVK{Float64})
end

F.can_imply(bp::TurnoverFromRawValues, ::Type{Nutrients.Nodes}) = !(bp.t isa Real)
Nutrients.Nodes(bp::TurnoverFromRawValues) =
    if bp.t isa Vector
        Nutrients.Nodes(length(bp.t))
    else
        Nutrients.Nodes(refs(bp.t))
    end

function F.check(model, bp::TurnoverFromRawValues)
    (; _nutrients_index) = model
    N = model.n_nutrients
    (; t) = bp
    @check_refs_if_list t :nutrient _nutrients_index dense
    @check_size_if_vector t N
end

function F.expand!(model, bp::TurnoverFromRawValues)
    (; _nutrients_index) = model
    N = model.n_nutrients
    (; t) = bp
    @to_dense_vector_if_map t _nutrients_index
    @to_size_if_scalar Real t N
    model._scratch[:nutrients_turnover] = t
end

@component TurnoverFromRawValues implies(Nutrients.Nodes)
export TurnoverFromRawValues

#-------------------------------------------------------------------------------------------
# @conflicts(TurnoverFromRawValues) # Keep in case more alternate blueprints are added.
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Turnover}) = Turnover

# ==========================================================================================
@expose_data nodes begin
    property(nutrients_turnover)
    get(TurnoverRates{Float64}, "nutrient")
    ref(m -> m._scratch[:nutrients_turnover])
    write!((m, rhs, i) -> (m._nutrients_turnover[i] = rhs))
    @nutrients_index
    depends(Turnover)
end

# ==========================================================================================
display_short(bp::Turnover; kwargs...) = display_short(bp, Turnover; kwargs...)
display_long(bp::Turnover; kwargs...) = display_long(bp, Turnover; kwargs...)
F.display(model, ::Type{<:Turnover}) =
    "Nutrients turnover: [$(join_elided(model._nutrients_turnover, ", "))]"
