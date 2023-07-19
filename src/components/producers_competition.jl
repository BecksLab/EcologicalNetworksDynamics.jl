# Set or generate producer competition rates
# for every producer-to-producer link in the model.

# Two blueprints: one from raw values,
# the other from diagonal elements.
# Although these do not differ in their dependencies,
# use the same patterns as other 'biorates' for consistency.

# ==========================================================================================
abstract type ProducersCompetition <: ModelBlueprint end
# All subtypes must require(Foodweb).

function ProducersCompetition(alpha = nothing; kwargs...)

    if isempty(kwargs)
        isnothing(alpha) && argerr("No input provided to specify producers competition.")
        ProducersCompetitionFromRawValues(alpha)
    else
        ProducersCompetitionFromDiagonal(; kwargs...)
    end

end

export ProducersCompetition

#-------------------------------------------------------------------------------------------
mutable struct ProducersCompetitionFromRawValues <: ProducersCompetition
    alpha::@GraphData {Scalar, SparseMatrix, Adjacency}{Float64}
    ProducersCompetitionFromRawValues(alpha) = new(@tographdata alpha SEA{Float64})
end

function F.check(model, bp::ProducersCompetitionFromRawValues)
    (; _producers_links, _species_index) = model
    (; alpha) = bp
    @check_refs_if_list alpha "producers link" _species_index template(_producers_links)
    @check_template_if_sparse alpha _producers_links "producers link"
end

function F.expand!(model, bp::ProducersCompetitionFromRawValues)
    (; _producers_links, _species_index) = model
    (; alpha) = bp
    ind = _species_index
    @to_sparse_matrix_if_adjacency alpha ind ind
    @to_template_if_scalar Real alpha _producers_links
    model._scratch[:producers_competition] = alpha
end

@component ProducersCompetitionFromRawValues requires(Foodweb)
export ProducersCompetitionFromRawValues

#-------------------------------------------------------------------------------------------
mutable struct ProducersCompetitionFromDiagonal <: ProducersCompetition
    diag::Float64
    off::Float64
    ProducersCompetitionFromDiagonal(d, o = 0) = new(d, o)
    function ProducersCompetitionFromDiagonal(; kwargs...)
        @kwargs_helpers kwargs
        alias!(:diag, :diagonal, :d)
        alias!(:off, :offdiagonal, :offdiag, :o, :rest, :nondiagonal, :nd)
        d = take_or!(:diag, 1.0)
        o = take_or!(:off, 0.0)
        no_unused_arguments()
        new(d, o)
    end
end

function F.expand!(model, bp::ProducersCompetitionFromDiagonal)
    (; S, _producers_links) = model
    (; diag, off) = bp

    alpha = spzeros((S, S))
    sources, targets, _ = findnz(_producers_links)
    for (i, j) in zip(sources, targets)
        alpha[i, j] = (i == j) ? diag : off
    end

    model._scratch[:producers_competition] = alpha
end

@component ProducersCompetitionFromDiagonal requires(Foodweb)
export ProducersCompetitionFromDiagonal

#-------------------------------------------------------------------------------------------
@conflicts(ProducersCompetitionFromRawValues, ProducersCompetitionFromDiagonal)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:ProducersCompetition}) = ProducersCompetition

# ==========================================================================================
@expose_data edges begin
    property(producers_competition)
    get(ProducersCompetitionRates{Float64}, sparse, "producer link")
    ref(m -> m._scratch[:producers_competition])
    template(m -> m._producers_links)
    write!((m, rhs, i, j) -> (m._scratch[:producers_competition][i, j] = rhs))
    @species_index
    depends(ProducersCompetition)
end

# ==========================================================================================
display_short(bp::ProducersCompetition; kwargs...) =
    display_short(bp, ProducersCompetition; kwargs...)
display_long(bp::ProducersCompetition; kwargs...) =
    display_long(bp, ProducersCompetition; kwargs...)

function F.display(model, ::Type{<:ProducersCompetition})
    nz = findnz(model._producers_competition)[3]
    "ProducersCompetition: " * if isempty(nz)
        "·"
    else
        min, max = minimum(nz), maximum(nz)
        if min == max
            "$min"
        else
            "ranging from $min to $max."
        end
    end
end
