# Subtypes commit to specifying
# the functional response required for the simulation to run,
# and all associated required data.
# They are all mutually exclusive.
abstract type FunctionalResponse <: ModelBlueprint end
export FunctionalResponse

#-------------------------------------------------------------------------------------------
mutable struct BioenergeticResponse <: FunctionalResponse
    e::Option{Efficiency}
    y::Option{MaximumConsumption}
    h::Option{HillExponent}
    w::Option{ConsumersPreferences}
    c::Option{IntraspecificInterference}
    half_saturation_density::Option{HalfSaturationDensity}
    BioenergeticResponse(; kwargs...) = new(
        fields_from_kwargs(
            BioenergeticResponse,
            kwargs;
            default = (
                e = :Miele2019,
                y = :Miele2019,
                h = 2,
                w = :homogeneous,
                c = 0,
                half_saturation_density = 0.5,
            ),
        )...,
    )
end

function F.expand!(model, ::BioenergeticResponse)
    s = model._scratch
    ber = Internals.BioenergeticResponse(
        s[:hill_exponent],
        s[:consumers_preferences],
        s[:intraspecific_interference],
        s[:half_saturation_density],
    )
    model.functional_response = ber
end

@component BioenergeticResponse
export BioenergeticResponse

#-------------------------------------------------------------------------------------------
mutable struct ClassicResponse <: FunctionalResponse
    M::Option{BodyMass}
    e::Option{Efficiency}
    h::Option{HillExponent}
    w::Option{ConsumersPreferences}
    c::Option{IntraspecificInterference}
    handling_time::Option{HandlingTime}
    attack_rate::Option{AttackRate}
    ClassicResponse(; kwargs...) = new(
        fields_from_kwargs(
            ClassicResponse,
            kwargs;
            default = (
                M = (Z = 1,),
                e = :Miele2019,
                h = 2,
                w = :homogeneous,
                c = 0,
                attack_rate = :Miele2019,
                handling_time = :Miele2019,
            ),
        )...,
    )
end

function F.expand!(model, ::ClassicResponse)
    s = model._scratch
    clr = Internals.ClassicResponse(
        s[:hill_exponent],
        s[:consumers_preferences],
        s[:intraspecific_interference],
        s[:handling_time],
        s[:attack_rate],
    )
    model.functional_response = clr
end

@component ClassicResponse
export ClassicResponse

#-------------------------------------------------------------------------------------------
mutable struct LinearResponse <: FunctionalResponse
    alpha::Option{ConsumptionRate}
    w::Option{ConsumersPreferences}
    LinearResponse(; kwargs...) = new(
        fields_from_kwargs(
            LinearResponse,
            kwargs;
            default = (alpha = 1, w = :homogeneous),
        )...,
    )
end

function F.expand!(model, ::LinearResponse)
    s = model._scratch
    lr = Internals.LinearResponse(s[:consumers_preferences], s[:consumption_rate])
    model.functional_response = lr
end

@component LinearResponse
export LinearResponse

#-------------------------------------------------------------------------------------------
# Set one, but not the others.
# TODO: this would be made easier set with an actual concept of 'Enum' components?
# (eg. all abstracts inheriting from `EnumBlueprint <: Blueprint`?)
@conflicts(BioenergeticResponse, ClassicResponse, LinearResponse)
@conflicts(BioenergeticResponse, NtiLayer)
@conflicts(LinearResponse, NtiLayer)
