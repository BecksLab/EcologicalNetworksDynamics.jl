# Subtypes commit to specifying the code
# associated with producer growth terms,
# and all associated required data.
# They are all mutually exclusive.
abstract type ProducerGrowth <: ModelBlueprint end
export ProducerGrowth

#-------------------------------------------------------------------------------------------
# Simple logistic growth.

mutable struct LogisticGrowth <: ProducerGrowth
    r::Option{GrowthRate}
    K::Option{CarryingCapacity}
    producers_competition::Option{ProducersCompetition}
    LogisticGrowth(; kwargs...) = new(
        fields_from_kwargs(
            LogisticGrowth,
            kwargs;
            default = (r = :Miele2019, K = 1, producers_competition = (; diag = 1)),
        )...,
    )
end

function F.expand!(model, ::LogisticGrowth)
    # Gather all data set up by brought components
    # to construct the actual functional response value.
    s = model._scratch
    lg = Internals.LogisticGrowth(
        # Alias so values gets updated on component `write!`.
        s[:producers_competition],
        s[:carrying_capacity],
        # Growth rates are already stored in `model.biorates` at this point.
    )
    model.producer_growth = lg
end

@component LogisticGrowth
export LogisticGrowth

#-------------------------------------------------------------------------------------------
# Nutrient intake.

# Convenience elision of e.g. 'nodes = 2': just use NutrientIntake(2) to bring nodes.
# Alternately, the number of nodes can be inferred
# from the non-scalar values if any is given.
mutable struct NutrientIntake <: ProducerGrowth
    r::Option{GrowthRate}
    nodes::Option{Nutrients.Nodes}
    turnover::Option{Nutrients.Turnover}
    supply::Option{Nutrients.Supply}
    concentration::Option{Nutrients.Concentration}
    half_saturation::Option{Nutrients.HalfSaturation}
    function NutrientIntake(nodes = missing; kwargs...)
        nodes = if haskey(kwargs, :nodes)
            ismissing(nodes) ||
                argerr("Nodes specified once as plain argument ($(repr(nodes))) \
                        and once as keyword argument (nodes = $(kwargs[:nodes])).")
            kwargs[:nodes]
        elseif ismissing(nodes)
            :one_per_producer
        else
            nodes
        end
        fields = fields_from_kwargs(
            NutrientIntake,
            kwargs;
            # Values from Brose2008.
            default = (;
                r = :Miele2019,
                nodes,
                turnover = 0.25,
                supply = 4,
                concentration = 0.5,
                half_saturation = 0.15,
            ),
        )
        new(fields...)
    end
end

function F.expand!(model, ::NutrientIntake)
    s = model._scratch
    ni = Internals.NutrientIntake(
        s[:nutrients_turnover],
        s[:nutrients_supply],
        s[:nutrients_concentration],
        s[:nutrients_half_saturation],
        s[:nutrients_names],
        s[:nutrients_index],
    )
    model.producer_growth = ni
end

@component NutrientIntake requires(Foodweb)
export NutrientIntake

#-------------------------------------------------------------------------------------------
# These are exclusive ways to specify producer growth.
@conflicts(LogisticGrowth, NutrientIntake)
@conflicts(NutrientIntake, NtiLayer)
