# Set or generate supply rates for every nutrients in the model.
#
# Mostly copied/adapted from nutrients turnover.

# ==========================================================================================
abstract type Supply <: ModelBlueprint end
# All subtypes must require(Nutrients.Nodes).

Supply(s) = SupplyFromRawValues(s)
export Supply

#-------------------------------------------------------------------------------------------
mutable struct SupplyFromRawValues <: Supply
    s::@GraphData {Scalar, Vector, Map}{Float64}
    SupplyFromRawValues(s) = new(@tographdata s SVK{Float64})
end

F.can_imply(bp::SupplyFromRawValues, ::Type{Nutrients.Nodes}) = !(bp.s isa Real)
Nutrients.Nodes(bp::SupplyFromRawValues) =
    if bp.s isa Vector
        Nutrients.Nodes(length(bp.s))
    else
        Nutrients.Nodes(refs(bp.s))
    end

function F.check(model, bp::SupplyFromRawValues)
    (; _nutrients_index) = model
    N = model.n_nutrients
    (; s) = bp
    @check_refs_if_list s :nutrient _nutrients_index dense
    @check_size_if_vector s N
end

function F.expand!(model, bp::SupplyFromRawValues)
    (; _nutrients_index) = model
    N = model.n_nutrients
    (; s) = bp
    @to_dense_vector_if_map s _nutrients_index
    @to_size_if_scalar Real s N
    model._scratch[:nutrients_supply] = s
end

@component SupplyFromRawValues implies(Nutrients.Nodes)
export SupplyFromRawValues

#-------------------------------------------------------------------------------------------
# @conflicts(SupplyFromRawValues) # Keep in case more alternate blueprints are added.
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Supply}) = Supply

# ==========================================================================================
@expose_data nodes begin
    property(nutrients_supply)
    get(SupplyRates{Float64}, "nutrient")
    ref(m -> m._scratch[:nutrients_supply])
    write!((m, rhs, i) -> (m._nutrients_supply[i] = rhs))
    @nutrients_index
    depends(Supply)
end

# ==========================================================================================
display_short(bp::Supply; kwargs...) = display_short(bp, Supply; kwargs...)
display_long(bp::Supply; kwargs...) = display_long(bp, Supply; kwargs...)
F.display(model, ::Type{<:Supply}) =
    "Nutrients supply: [$(join_elided(model._nutrients_supply, ", "))]"
