# Set or generate consumers preferences rates for every trophic link in the model.

# ConsumersPreferences rates are either given as-is by user
# or they are set as "homogeneous" based on the network.
# One blueprint is enough for this,
# but use the same patterns as other 'biorates' for consistency.

# ==========================================================================================
abstract type ConsumersPreferences <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input.
ConsumersPreferences(w) = ConsumersPreferencesFromRawValues(w)
export ConsumersPreferences

#-------------------------------------------------------------------------------------------
# First variant: user provides raw consumers preferences rates.

mutable struct ConsumersPreferencesFromRawValues <: ConsumersPreferences
    w::@GraphData {Symbol, SparseMatrix}{Float64}
    function ConsumersPreferencesFromRawValues(w)
        # Redundant with later, proper check, but this doesn't hurt.
        @check_if_symbol w :homogeneous
        new(@tographdata w YE{Float64})
    end
end

function F.check(model, bp::ConsumersPreferencesFromRawValues)
    (; _A) = model
    (; w) = bp
    @check_if_symbol w :homogeneous
    @check_template_if_sparse w _A "trophic link"
end

function F.expand!(model, bp::ConsumersPreferencesFromRawValues)
    (; _foodweb) = model
    (; w) = bp
    @expand_if_symbol(w, :homogeneous => Internals.homogeneous_preference(_foodweb))
    model._scratch[:consumers_preferences] = w
end

@component ConsumersPreferencesFromRawValues requires(Foodweb)
export ConsumersPreferencesFromRawValues

#-------------------------------------------------------------------------------------------
# Keep in case more alternate blueprints are added.
# @conflicts(ConsumersPreferencesFromRawValues)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:ConsumersPreferences}) = ConsumersPreferences

# ==========================================================================================
@expose_data edges begin
    property(consumers_preferences, w)
    get(ConsumersPreferencesWeights{Float64}, sparse, "trophic link")
    ref(m -> m._scratch[:consumers_preferences])
    template(m -> m._A)
    write!((m, rhs, i, j) -> (m._consumers_preferences[i, j] = rhs))
    @species_index
    depends(ConsumersPreferences)
end

# ==========================================================================================
display_short(bp::ConsumersPreferences; kwargs...) =
    display_short(bp, ConsumersPreferences; kwargs...)
display_long(bp::ConsumersPreferences; kwargs...) =
    display_long(bp, ConsumersPreferences; kwargs...)
function F.display(model, ::Type{<:ConsumersPreferences})
    nz = findnz(model._w)[3]
    "Consumers preferences: " * if isempty(nz)
        "·"
    else
        min, max = minimum(nz), maximum(nz)
        if min == max
            "$min"
        else
            "$min to $max."
        end
    end
end
