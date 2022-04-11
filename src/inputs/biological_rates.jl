#=
Biological rates
=#

"""Which species is a producer (1) or not (0)?"""
function whoisproducer(A)
    vec(.!any(A, dims=2))
end

function whois(metabolic_class::String, foodweb::FoodWeb)
    vec(foodweb.metabolic_class .== metabolic_class)
end
function whoisproducer(foodweb::FoodWeb)
    whois("producer", foodweb)
end
function whoisvertebrate(foodweb::FoodWeb)
    whois("ectotherm vertebrate", foodweb)
end
function whoisinvertebrate(foodweb::FoodWeb)
    whois("invertebrate", foodweb)
end

"""
    allometricgrowth(foodweb)

Calculate producers (basal species) growth rate with allometric equation.
"""
function allometricgrowth(
    foodweb::FoodWeb;
    a::Union{Vector{T},T}=1,
    b::Union{Vector{T},T}=-0.25
) where {T<:Real}
    allometricscale.(a, b, foodweb.M) .* whoisproducer(foodweb)
end

"""Allometric scaling: parameter expressed as a power law of body-mass (M)."""
allometricscale(a, b, M) = a * M^b

struct ParamsGrowth
    aₚ::Real
    aₑ::Real
    aᵢ::Real
    bₚ::Real
    bₑ::Real
    bᵢ::Real
    ParamsGrowth(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) = new(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) # custom
    ParamsGrowth() = new(1.0, 0.0, 0.0, -0.25, 0.0, 0.0) # default
end
struct ParamsMetabolism
    aₚ::Real
    aₑ::Real
    aᵢ::Real
    bₚ::Real
    bₑ::Real
    bᵢ::Real
    ParamsMetabolism(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) = new(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) # custom
    ParamsMetabolism() = new(0, 0.88, 0.314, 0, -0.25, -0.25) # default
end

"""
Create species parameter vectors for a, b of length S (species richness) given the
allometric parameters for the different metabolic classes (aₚ,aᵢ,...).
"""
function default_params(
    foodweb::FoodWeb,
    params
)

    # Test
    validclasses = ["producer", "invertebrate", "ectotherm vertebrate"]
    isclassvalid(class) = class ∈ validclasses
    all(isclassvalid.(foodweb.metabolic_class)) || throw(ArgumentError("Metabolic classes
        should be in $(validclasses)"))

    # Set up
    S = richness(foodweb)
    a, b = zeros(S), zeros(S)

    # Fill a
    a[whoisproducer(foodweb)] .= params.aₚ
    a[whoisinvertebrate(foodweb)] .= params.aᵢ
    a[whoisvertebrate(foodweb)] .= params.aₑ

    # Fill b
    b[whoisproducer(foodweb)] .= params.bₚ
    b[whoisinvertebrate(foodweb)] .= params.bᵢ
    b[whoisvertebrate(foodweb)] .= params.bₑ

    (a=a, b=b)
end

"""Internal function to compute vector (one value per species) of a given rate."""
function allometric_rate(
    foodweb::FoodWeb,
    params
)
    a, b = params.a, params.b
    allometricscale.(a, b, foodweb.M)
end

"""
    allometricmetabolism(foodweb)

Calculate species metabolic demands (x) with allometric equation.
"""
function allometric_metabolism(
    foodweb::FoodWeb;
    params=default_params(foodweb, ParamsMetabolism())
)

    allometric_rate(foodweb, params)
end

struct ParamsMaxConsumption
    aₚ::Real
    aₑ::Real
    aᵢ::Real
    bₚ::Real
    bₑ::Real
    bᵢ::Real
    ParamsMaxConsumption(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) = new(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ) # custom
    ParamsMaxConsumption() = new(0.0, 4.0, 8.0, 0.0, 0.0, 0.0) # default
end

"""
    allometricmaxconsumption(foodweb)

Calculate species metabolic max consumption (y) with allometric equation.
"""
function allometricmaxconsumption(foodweb::FoodWeb; a::Union{Vector{T},T,Nothing}=nothing, b::Union{Vector{T},T,Nothing}=nothing, a_ect::Real=4.0, a_inv::Real=8.0, b_ect::Real=0, b_inv::Real=0) where {T<:Real}

    S = richness(foodweb)
    if isnothing(a) & isnothing(b)
        checkclass = all([m ∈ ["producer", "invertebrate", "ectotherm vertebrate"] for m in foodweb.metabolic_class])
        checkclass || throw(ArgumentError("By not providing any values, you are using the default allometric parameters, but to do that you need to have only producers, invertebrates and/or ectotherm vertebrates in your metabolic_class vector"))
        a, b = _defaulparameters_maxconsumption(foodweb, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv)
    elseif isnothing(a) & !isnothing(b)
        a = _defaulparameters_maxconsumption(foodweb, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv).a
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & isnothing(b)
        b = _defaulparameters_maxconsumption(foodweb, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv).b
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & !isnothing(b)
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    end
    x = a .* (foodweb.M .^ b)
    isp = whoisproducer(foodweb.A)
    x[isp] .= 0.0
    return x
end

function _defaulparameters_maxconsumption(FW; a_ect::Real=4, a_inv::Real=8, b_ect::Real=0, b_inv::Real=0)
    a = zeros(length(FW.species))
    a[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= a_ect
    a[vec(FW.metabolic_class .== "invertebrate")] .= a_inv
    b = zeros(length(FW.species))
    b[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= b_ect
    b[vec(FW.metabolic_class .== "invertebrate")] .= b_inv
    return (a=a, b=b)
end

"""
    TODO
"""
function BioRates(FW::FoodWeb
    ; rmodel::Union{Function,Nothing}=allometricgrowth, rparameters::Union{NamedTuple,Nothing}=nothing, xmodel::Union{Function,Nothing}=allometricmetabolism, xparameters::Union{NamedTuple,Nothing}=nothing, ymodel::Union{Function,Nothing}=allometricmaxconsumption, yparameters::Union{NamedTuple,Nothing}=nothing, r::Union{Vector{<:Real},Nothing}=nothing, x::Union{Vector{<:Real},Nothing}=nothing, y::Union{Vector{<:Real},Nothing}=nothing
)

    isnothing(rparameters) || _checkparamtupleR(rparameters)
    isnothing(xparameters) || _checkparamtupleX(xparameters)
    isnothing(yparameters) || _checkparamtupleY(yparameters)

    S = richness(FW)

    if !isnothing(r)
        isequal(length(r))(S) || throw(ArgumentError("r should be a vector of length richness(FW)"))
    else
        if isnothing(rparameters)
            r = rmodel(FW)
        else
            _checkparamtupleR(rparameters)
            rp = Dict(map((i, j) -> i => j, keys(rparameters), values(rparameters)))
            r = rmodel(FW; rp...)
        end
    end

    if !isnothing(x)
        isequal(length(x))(S) || throw(ArgumentError("x should be a vector of length richness(FW)"))
    else
        if isnothing(xparameters)
            x = xmodel(FW)
        else
            _checkparamtupleX(xparameters)
            xp = Dict(map((i, j) -> i => j, keys(xparameters), values(xparameters)))
            x = rmodel(FW; xp...)
        end
    end

    if !isnothing(y)
        isequal(length(y))(S) || throw(ArgumentError("y should be a vector of length richness(FW)"))
    else
        if isnothing(yparameters)
            y = ymodel(FW)
        else
            _checkparamtupleY(yparameters)
            yp = Dict(map((i, j) -> i => j, keys(yparameters), values(yparameters)))
            y = rmodel(FW; yp...)
        end
    end

    return BioRates(r, x, y)

end

function _checkparamtupleR(nt::NamedTuple)
    expectednames = ["a", "b"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the growth rate should be specified in a NamedTuple with fields a (constants) and b (exponents). More details in the docs."))
end

function _checkparamtupleX(nt::NamedTuple)
    expectednames = ["a", "b", "a_p", "b_p", "a_ect", "b_ect", "a_inv", "b_inv"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the metabolic rate should be specified in a NamedTuple with possible fields: a, b, a_p, b_p, a_inv, b_inv, a_ect, b_ect. More details in the docs."))
end

function _checkparamtupleY(nt::NamedTuple)
    expectednames = ["a", "b", "a_ect", "b_ect", "a_inv", "b_inv"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the max. consumption rate should be specified in a NamedTuple with possible fields: a, b, a_inv, b_inv, a_ect, b_ect. More details in the docs."))
end
