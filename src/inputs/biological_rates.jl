#=
Biological rates
=#

#### Constructors containing default parameter value for allometric scaled rates ####
DefaultGrowthParams() = AllometricParams(1.0, 0.0, 0.0, -0.25, 0.0, 0.0)
DefaultMetabolismParams() = AllometricParams(0, 0.88, 0.314, 0, -0.25, -0.25)
DefaultMaxConsumptionParams() = AllometricParams(0.0, 4.0, 8.0, 0.0, 0.0, 0.0)

struct AllometricParams
    aₚ::Real
    aₑ::Real
    aᵢ::Real
    bₚ::Real
    bₑ::Real
    bᵢ::Real
end
#### end ####

#### Main functions to compute biological rates ####
"""
    BioRates(foodweb)

Compute the biological rates of each species in the system.
The rates are:
- the growth rate (r)
- the metabolic rate or metabolic demand (x)
- the maximum consumption rate (y)
If no value are provided for the rates, they take default values assuming an allometric
scaling. Custom values can be provided for one or several rates by giving a vector of
length 1 or S (species richness). Moreover, if one want to use allometric scaling
(rate = aMᵇ) but do not want to use default values for a and b, one can simply call
`allometricrate` with custom `AllometricParams`.
"""
function BioRates(
    foodweb::FoodWeb;
    r::Union{Vector{<:Real},<:Real}=allometricrate(foodweb, DefaultGrowthParams()),
    x::Union{Vector{<:Real},<:Real}=allometricrate(foodweb, DefaultMetabolismParams()),
    y::Union{Vector{<:Real},<:Real}=allometricrate(foodweb, DefaultMaxConsumptionParams())
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

"Compute rate vector (one value per species) with allometric scaling."
function allometricrate(
    foodweb::FoodWeb,
    allometricparams::AllometricParams
)
    params = allometricparams_to_vec(foodweb, allometricparams)
    a, b = params.a, params.b
    allometricscale.(a, b, foodweb.M)
end
#### end ####

#### Helper functions to compute allometric rates ####
"Allometric scaling: parameter expressed as a power law of body-mass (M)."
allometricscale(a, b, M) = a * M^b

"""
Create species parameter vectors for a, b of length S (species richness) given the
allometric parameters for the different metabolic classes (aₚ,aᵢ,...).
"""
function allometricparams_to_vec(
    foodweb::FoodWeb,
    params::AllometricParams
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
#### end ####

#### Identifying metabolic classes ####
"Which species is a producer (1) or not (0)?"
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
