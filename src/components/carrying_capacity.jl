# Set or generate carrying capacity for every producer in the model.
#
# Two blueprint variants "for the same component",
# depending on whether raw values or allometric rules for temperature are used.

abstract type CarryingCapacity <: ModelBlueprint end
# All subtypes must require(Foodweb).

# Construct either variant based on user input,
# but disallow direct allometric input in this constructor,
# for consistence with other allometry-compliant biorates.
function CarryingCapacity(K)

    @check_if_symbol K (:Binzer2016,)

    if K == :Binzer2016
        CarryingCapacityFromTemperature(K)
    else
        CarryingCapacityFromRawValues(K)
    end

end

export CarryingCapacity

#-------------------------------------------------------------------------------------------
mutable struct CarryingCapacityFromRawValues <: CarryingCapacity
    K::@GraphData {Scalar, SparseVector, Map}{Float64}
    CarryingCapacityFromRawValues(K) = new(@tographdata K SNK{Float64})
end

function F.check(model, bp::CarryingCapacityFromRawValues)
    (; _producers_mask, _producers_sparse_index) = model
    (; K) = bp
    @check_refs_if_list K :producers _producers_sparse_index
    @check_template_if_sparse K _producers_mask :producers
end

function store_legacy_K!(model, K::SparseVector{Float64})
    # The legacy format is a dense vector with 'nothing' values.
    res = Union{Nothing,Float64}[nothing for i in 1:length(K)]
    for (i, k) in zip(findnz(K)...)
        res[i] = k
    end
    # Store in scratch space until we're sure to bring in the "LogisticGrowth" component.
    model._scratch[:carrying_capacity] = res
    # Keep a true sparse version in the cache.
    model._cache[:carrying_capacity] = K
end

function F.expand!(model, bp::CarryingCapacityFromRawValues)
    (; _producers_mask, _species_index) = model
    (; K) = bp
    @to_sparse_vector_if_map K _species_index
    @to_template_if_scalar Real K _producers_mask
    store_legacy_K!(model, K)
end

@component CarryingCapacityFromRawValues requires(Foodweb)
export CarryingCapacityFromRawValues

#-------------------------------------------------------------------------------------------
binzer2016_carrying_capacity_allometry_rates() =
    (E_a = 0.71, allometry = Allometry(; producer = (a = 3, b = 0.28)))

mutable struct CarryingCapacityFromTemperature <: CarryingCapacity
    E_a::Float64
    allometry::Allometry
    CarryingCapacityFromTemperature(E_a; kwargs...) =
        new(E_a, parse_allometry_arguments(kwargs))
    CarryingCapacityFromTemperature(E_a, allometry::Allometry) = new(E_a, allometry)
    function CarryingCapacityFromTemperature(default::Symbol)
        @check_if_symbol default (:Binzer2016,)
        return @build_from_symbol default (
            :Binzer2016 => new(binzer2016_carrying_capacity_allometry_rates()...)
        )
    end
end

F.buildsfrom(::CarryingCapacityFromTemperature) = [Temperature, BodyMass, MetabolicClass]

function F.check(_, bp::CarryingCapacityFromTemperature)
    al = bp.allometry
    (_, template) = binzer2016_carrying_capacity_allometry_rates()
    check_template(al, template, "carrying capacity rate from temperature")
end

function F.expand!(model, bp::CarryingCapacityFromTemperature)
    (; _M, T, _metabolic_classes, _producers_mask) = model
    (; E_a) = bp
    K = sparse_nodes_allometry(
        bp.allometry,
        _producers_mask,
        _M,
        _metabolic_classes;
        E_a,
        T,
    )
    store_legacy_K!(model, K)
end

@component CarryingCapacityFromTemperature requires(Foodweb)
export CarryingCapacityFromTemperature

#-------------------------------------------------------------------------------------------
@conflicts(CarryingCapacityFromRawValues, CarryingCapacityFromTemperature)
# Temporary semantic fix before framework refactoring.
F.componentof(::Type{<:CarryingCapacity}) = CarryingCapacity

# ==========================================================================================
@expose_data nodes begin
    property(carrying_capacity, K)
    get(CarryingCapacities{Float64}, sparse, "producer")
    ref_cache(m -> nothing) # Cache loaded on component expansion.
    template(m -> m._producers_mask)
    write!((m, rhs, i) -> (m._scratch[:carrying_capacity][i] = rhs))
    @species_index
    depends(CarryingCapacity)
end

# ==========================================================================================
display_short(bp::CarryingCapacity; kwargs...) =
    display_short(bp, CarryingCapacity; kwargs...)
display_long(bp::CarryingCapacity; kwargs...) =
    display_long(bp, CarryingCapacity; kwargs...)
F.display(model, ::Type{<:CarryingCapacity}) =
    "Carrying capacity: [$(join_elided(model._K, ", "))]"
