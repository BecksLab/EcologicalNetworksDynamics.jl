# Set or generate attack rates for every trophic link in the model.
#
# Adapted from handling times.

# ==========================================================================================
abstract type AttackRate <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input,
# but disallow direct allometric input in this constructor,
# for consistence with other allometry-compliant biorates.
function AttackRate(a_r)

    @check_if_symbol a_r (:Miele2019, :Binzer2016)

    if a_r == :Binzer2016
        AttackRateFromTemperature(a_r)
    else
        AttackRateFromRawValues(a_r)
    end

end

export AttackRate

#-------------------------------------------------------------------------------------------
mutable struct AttackRateFromRawValues <: AttackRate
    a_r::@GraphData {Scalar, Symbol, SparseMatrix, Adjacency}{Float64}
    function AttackRateFromRawValues(a_r)
        @check_if_symbol a_r (:Miele2019,)
        new(@tographdata a_r SYEA{Float64})
    end
end

# Default rates from Miele2019 require a value of M.
F.buildsfrom(bp::AttackRateFromRawValues) =
    (bp.a_r == :Miele2019) ?
    [BodyMass => "Miele2019 method for calculating attack rates \
                  requires individual body mass data."] : []

function F.check(model, bp::AttackRateFromRawValues)
    (; _A, _species_index) = model
    (; a_r) = bp
    @check_if_symbol a_r (:Miele2019,)
    @check_refs_if_list a_r "trophic link" _species_index template(_A)
    @check_template_if_sparse a_r _A "trophic link"
end

function F.expand!(model, bp::AttackRateFromRawValues)
    (; _A, _species_index) = model
    (; a_r) = bp
    ind = _species_index
    @expand_if_symbol(a_r, :Miele2019 => Internals.attack_rate(model._foodweb))
    @to_sparse_matrix_if_adjacency a_r ind ind
    @to_template_if_scalar Real a_r _A
    model._scratch[:attack_rate] = a_r
end

@component AttackRateFromRawValues requires(Foodweb)
export AttackRateFromRawValues

#-------------------------------------------------------------------------------------------
binzer2016_attack_rate_allometry_rates() = (
    E_a = -0.38,
    allometry = Allometry(;
        producer = (a = 0, b = 0.25, c = -0.8), # ? Is that intended @hanamayall?
        invertebrate = (a = exp(-13.1), b = 0.25, c = -0.8),
        ectotherm = (a = exp(-13.1), b = 0.25, c = -0.8),
    ),
)

mutable struct AttackRateFromTemperature <: AttackRate
    E_a::Float64
    allometry::Allometry
    AttackRateFromTemperature(E_a; kwargs...) = new(E_a, parse_allometry_arguments(kwargs))
    AttackRateFromTemperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function AttackRateFromTemperature(default::Symbol)
        @check_if_symbol default (:Binzer2016,)
        return @build_from_symbol default (
            :Binzer2016 => new(binzer2016_attack_rate_allometry_rates()...)
        )
    end
end

F.buildsfrom(::AttackRateFromTemperature) = [Temperature, BodyMass, MetabolicClass]

function F.check(_, bp::AttackRateFromTemperature)
    al = bp.allometry
    (_, template) = binzer2016_attack_rate_allometry_rates()
    check_template(al, template, "attack rates from temperature")
end

function F.expand!(model, bp::AttackRateFromTemperature)
    (; _M, T, _metabolic_classes, _A) = model
    (; E_a) = bp
    a_r = sparse_edges_allometry(bp.allometry, _A, _M, _metabolic_classes; E_a, T)
    model._scratch[:attack_rate] = a_r
end

@component AttackRateFromTemperature requires(Foodweb)
export AttackRateFromTemperature

#-------------------------------------------------------------------------------------------
@conflicts(AttackRateFromRawValues, AttackRateFromTemperature)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:AttackRate}) = AttackRate

# ==========================================================================================
@expose_data edges begin
    property(attack_rate)
    get(AttackRates{Float64}, sparse, "trophic link")
    ref(m -> m._scratch[:attack_rate])
    template(m -> m._A)
    write!((m, rhs, i, j) -> (m._attack_rate[i, j] = rhs))
    @species_index
    depends(AttackRate)
end

# ==========================================================================================
display_short(bp::AttackRate; kwargs...) = display_short(bp, AttackRate; kwargs...)
display_long(bp::AttackRate; kwargs...) = display_long(bp, AttackRate; kwargs...)
function F.display(model, ::Type{<:AttackRate})
    nz = findnz(model._attack_rate)[3]
    "Attack rates: " * if isempty(nz)
        "·"
    else
        min, max = minimum(nz), maximum(nz)
        if min == max
            "$min"
            "$min"
        else
            "$min to $max."
        end
    end
end
