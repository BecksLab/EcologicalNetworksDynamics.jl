#=
Biological rates
=#

#### Function for rates with allometric scaling ####
"""
    allometricgrowth(foodweb)

Calculate producers (basal species) growth rate with allometric equation.
"""
function allometricgrowth(
    foodweb::FoodWeb;
    params=default_params(foodweb, ParamsGrowth())
)
    allometric_rate(foodweb, params)
end

"""
    allometricmetabolism(foodweb)

Calculate species metabolic demands (x) with allometric equation.
"""
function allometricmetabolism(
    foodweb::FoodWeb;
    params=default_params(foodweb, ParamsMetabolism())
)
    allometric_rate(foodweb, params)
end

"""
    allometricmaxconsumption(foodweb)

Calculate species metabolic max consumption (y) with allometric equation.
"""
function allometricmaxconsumption(
    foodweb::FoodWeb;
    params=default_params(foodweb, ParamsMaxConsumption())
)
    allometric_rate(foodweb, params)
end
#### end ####

#### Helper functions to compute allometric rates ####
"""Allometric scaling: parameter expressed as a power law of body-mass (M)."""
allometricscale(a, b, M) = a * M^b

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
#### end ####

#### Constructors containing default parameter value for allometric scaled rates ####
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
#### end ####

#### Identifying metabolic classes ####
"""Which species is a producer (1) or not (0)?"""
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

function whoisproducer(A)
    vec(.!any(A, dims=2))
end
#### end ####

"""
    TODO
"""
function BioRates(
    foodweb::FoodWeb;
    r::Union{Vector{<:Real},<:Real}=allometricgrowth(foodweb),
    x::Union{Vector{<:Real},<:Real}=allometricmetabolism(foodweb),
    y::Union{Vector{<:Real},<:Real}=allometricmaxconsumption(foodweb)
)

    # Set up
    S = richness(foodweb)
    Rates = [r, x, y]
    nᵣ = length(Rates)

    # Test and format rates
    for i in 1:nᵣ
        rate = Rates[i]
        length(rate) ∈ [1, S] || throw(ArgumentError("Rate should be of length 1 or S."))
        typeof(rate) <: Real && (rate = [rate]) # convert 'rate' to vector
        length(rate) == S || (Rates[i] = repeat(rate, S)) # length 1 -> length S
    end

    # Output
    r, x, y = Rates # recover formated rates
    BioRates(r, x, y)
end
