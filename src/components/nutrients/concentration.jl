# Set or generate concentrations for every producer-to-nutrient link in the model.
#
# These links are not reified with anything akin to a *mask* yet,
# because there are stored densely in the legacy internals for now
# as a n_producers × n_nutrients matrix.
# TODO: this raises the question of the size of templated nodes/edges data:
#   - sparse, with the size of their compartment (eg. S with missing values for consumers).
#   - dense, with the size of the filtered compartment (eg. n_producers)
#     and then care must be taken while indexing it.

# ==========================================================================================
abstract type Concentration <: ModelBlueprint end
# All subtypes must require(Nutrients.Nodes,Foodweb).

Concentration(c) = ConcentrationFromRawValues(c)
export Concentration

#-------------------------------------------------------------------------------------------
# TODO: it used to be possible to specify concentration row-wise..
# but is that really a good idea regarding the confusion with column-wise?
# Also disallow adjacency list input because of the same confusion.
mutable struct ConcentrationFromRawValues <: Concentration
    c::@GraphData {Scalar, Matrix}{Float64}
    ConcentrationFromRawValues(c) = new(@tographdata c SM{Float64})
end

F.can_imply(bp::ConcentrationFromRawValues, ::Type{Nutrients.Nodes}) = !(bp.c isa Real)
Nutrients.Nodes(bp::ConcentrationFromRawValues) = Nutrients.Nodes(size(bp.c, 2))

function F.check(model, bp::ConcentrationFromRawValues)
    (; n_producers, n_nutrients) = model
    (; c) = bp
    @check_size_if_matrix c (n_producers, n_nutrients)
end

function F.expand!(model, bp::ConcentrationFromRawValues)
    (; n_producers, n_nutrients) = model
    (; c) = bp
    @to_size_if_scalar Real c (n_producers, n_nutrients)
    model._scratch[:nutrients_concentration] = c
end

@component ConcentrationFromRawValues requires(Foodweb) implies(Nutrients.Nodes)
export ConcentrationFromRawValues

#-------------------------------------------------------------------------------------------
# @conflicts(ConcentrationFromRawValues) # Keep in case more alternate blueprints are added.
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:Concentration}) = Concentration

# ==========================================================================================
@expose_data edges begin
    property(nutrients_concentration)
    get(Concentrations{Float64}, "producer-to-nutrient link")
    ref(m -> m._scratch[:nutrients_concentration])
    write!((m, rhs, i, j) -> (m._nutrients_concentration[i, j] = rhs))
    row_index(m -> m._producers_dense_index)
    col_index(m -> m._nutrients_index)
    depends(Concentration)
end

# ==========================================================================================
display_short(bp::Concentration; kwargs...) = display_short(bp, Concentration; kwargs...)
display_long(bp::Concentration; kwargs...) = display_long(bp, Concentration; kwargs...)
function F.display(model, ::Type{<:Concentration})
    c = model.nutrients_concentration
    min, max = minimum(c), maximum(c)
    "Nutrients concentration: " * if min == max
        "$min"
    else
        "ranging from $min to $max."
    end
end
