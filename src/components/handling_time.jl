# Set or generate handling times for every trophic link in the model.
#
# Handling times are either given as raw values,
# or they are calculated from temperature-dependent allometric rules.
#
# Adapted from efficiency (for raw values)
# and carrying capacity (for temperature dependence).

# ==========================================================================================
abstract type HandlingTime <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input,
# but disallow direct allometric input in this constructor,
# for consistence with other allometry-compliant biorates.
function HandlingTime(h_t)

    @check_if_symbol h_t (:Miele2019, :Binzer2016)

    if h_t == :Binzer2016
        HandlingTimeFromTemperature(h_t)
    else
        HandlingTimeFromRawValues(h_t)
    end

end

export HandlingTime

#-------------------------------------------------------------------------------------------
mutable struct HandlingTimeFromRawValues <: HandlingTime
    h_t::@GraphData {Scalar, Symbol, SparseMatrix, Adjacency}{Float64}
    function HandlingTimeFromRawValues(h_t)
        @check_if_symbol h_t (:Miele2019,)
        new(@tographdata h_t SYEA{Float64})
    end
end

# Default times from Miele2019 require a value of M.
F.buildsfrom(bp::HandlingTimeFromRawValues) =
    (bp.h_t == :Miele2019) ?
    [BodyMass => "Miele2019 method for calculating handling times \
                  requires individual body mass data."] : []

function F.check(model, bp::HandlingTimeFromRawValues)
    (; _A, _species_index) = model
    (; h_t) = bp
    @check_if_symbol h_t (:Miele2019,)
    @check_refs_if_list h_t "trophic link" _species_index template(_A)
    @check_template_if_sparse h_t _A "trophic link"
end

function F.expand!(model, bp::HandlingTimeFromRawValues)
    (; _A, _species_index) = model
    (; h_t) = bp
    ind = _species_index
    @expand_if_symbol(h_t, :Miele2019 => Internals.handling_time(model._foodweb))
    @to_sparse_matrix_if_adjacency h_t ind ind
    @to_template_if_scalar Real h_t _A
    model._scratch[:handling_time] = h_t
end

@component HandlingTimeFromRawValues requires(Foodweb)
export HandlingTimeFromRawValues

#-------------------------------------------------------------------------------------------
binzer2016_handling_time_allometry_rates() = (
    E_a = 0.26,
    allometry = Allometry(;
        producer = (a = 0, b = -0.45, c = 0.47), # ? Is that intended @hanamayall?
        invertebrate = (a = exp(9.66), b = -0.45, c = 0.47),
        ectotherm = (a = exp(9.66), b = -0.45, c = 0.47),
    ),
)

mutable struct HandlingTimeFromTemperature <: HandlingTime
    E_a::Float64
    allometry::Allometry
    HandlingTimeFromTemperature(E_a; kwargs...) =
        new(E_a, parse_allometry_arguments(kwargs))
    HandlingTimeFromTemperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function HandlingTimeFromTemperature(default::Symbol)
        @check_if_symbol default (:Binzer2016,)
        return @build_from_symbol default (
            :Binzer2016 => new(binzer2016_handling_time_allometry_rates()...)
        )
    end
end

F.buildsfrom(::HandlingTimeFromTemperature) = [Temperature, BodyMass, MetabolicClass]

function F.check(_, bp::HandlingTimeFromTemperature)
    al = bp.allometry
    (_, template) = binzer2016_handling_time_allometry_rates()
    check_template(al, template, "handling times from temperature")
end

function F.expand!(model, bp::HandlingTimeFromTemperature)
    (; _M, T, _metabolic_classes, _A) = model
    (; E_a) = bp
    h_t = sparse_edges_allometry(bp.allometry, _A, _M, _metabolic_classes; E_a, T)
    model._scratch[:handling_time] = h_t
end

@component HandlingTimeFromTemperature requires(Foodweb)
export HandlingTimeFromTemperature

#-------------------------------------------------------------------------------------------
@conflicts(HandlingTimeFromRawValues, HandlingTimeFromTemperature)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:HandlingTime}) = HandlingTime

# ==========================================================================================
@expose_data edges begin
    property(handling_time)
    get(HandlingTimes{Float64}, sparse, "trophic link")
    ref(m -> m._scratch[:handling_time])
    template(m -> m._A)
    write!((m, rhs, i, j) -> (m._handling_time[i, j] = rhs))
    @species_index
    depends(HandlingTime)
end

# ==========================================================================================
display_short(bp::HandlingTime; kwargs...) = display_short(bp, HandlingTime; kwargs...)
display_long(bp::HandlingTime; kwargs...) = display_long(bp, HandlingTime; kwargs...)
function F.display(model, ::Type{<:HandlingTime})
    nz = findnz(model._handling_time)[3]
    "Handling time: " * if isempty(nz)
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
