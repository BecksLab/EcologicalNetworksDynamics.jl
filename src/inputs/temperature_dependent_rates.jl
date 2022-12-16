#=
Temperature dependent rates 
=#

abstract type TemperatureResponse end

"""
    ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

Parameters used to compute temperature dependent rates for different metabolic classes using a Exponential Boltzmann Arrhenius method of
The rate R is expressed as follow: ``R = aMᵢᵇMⱼᶜexp(Eₐ(T-T0)/kTT0)``, where a, b and c can take different values
depending on the metabolic class of the species, although by default these do not vary as such. Growth and metabolic
rate scale allometrically solely with species i, whereas feeding rates (y, B0, Th, ar) also depend on the body mass of
resource species j.  a is the intercept, b is the allometric exponent of the resource, c is the allometric exponent of the consumer.
This struct aims at storing these values of a, b & c and the activation energy Eₐ for each rate. Specifically:

  - aₚ: a for producers
  - aₑ: a for ectotherm vertebrates
  - aᵢ: a for invertebrates
  - bₚ: b for producers
  - bₑ: b for ectotherm vertebrates
  - bᵢ: b for invertebrates
  - cₚ: c for producers
  - cₑ: c for ectotherm vertebrates
  - cᵢ: c for invertebrates
  - Eₐ: activation energy

Default parameters values taken from the literature for certain rates can be accessed by
calling the corresponding function, for:

  - Exponential Boltzmann Arrhenius growth rate (r) call [`DefaultExpBAGrowthParams`](@ref)
  - Exponential Boltzmann Arrhenius metabolic rate (x) call [`DefaultExpBAMetabolismParams`](@ref)
"""
struct ExponentialBAParams
    aₚ::Union{Real,Nothing}
    aₑ::Union{Real,Nothing}
    aᵢ::Union{Real,Nothing}
    bₚ::Real
    bₑ::Real
    bᵢ::Real
    cₚ::Real
    cₑ::Real
    cᵢ::Real
    Eₐ::Real
end


#### Constructors containing default parameter value for temperature scaled rates ####
"""
    DefaultExpBAGrowthParams()

Default temp dependent and allometric parameters (a, b, c, Eₐ) values for growth rate (r). ([Savage et al., 2004](https://doi.org/10.1086/381872), [Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
DefaultExpBAGrowthParams() =
    ExponentialBAParams(exp(-15.68), 0, 0, -0.25, -0.25, -0.25, 0, 0, 0, -0.84)
"""
    DefaultExpBAMetabolismParams()

Default temp dependent and allometric parameters (a, b, c, Eₐ) values for metabolic rate (x).([Ehnes et al., 2011](https://doi.org/10.1111/j.1461-0248.2011.01660.x), [Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
DefaultExpBAMetabolismParams() =
    ExponentialBAParams(0, exp(-16.54), exp(-16.54), -0.31, -0.31, -0.31, 0, 0, 0, -0.69)

"""
    DefaultExpBAHandlingTimeParams()

Default temp dependent and allometric parameters (a, b, c, Eₐ) values for handling time (hₜ). ([Rall et al., 2012](https://doi.org/10.1098/rstb.2012.0242), [Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
DefaultExpBAHandlingTimeParams() = ExponentialBAParams(
    0,
    exp(9.66),
    exp(9.66),
    -0.45,
    -0.45,
    -0.45,
    0.47,
    0.47,
    0.47,
    0.26,
)

"""
    DefaultExpBAAttackRateParams()

Default temp dependent and allometric parameters (a, b, c, Eₐ) values for attack rate (aᵣ).([Rall et al., 2012](https://doi.org/10.1098/rstb.2012.0242), [Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
DefaultExpBAAttackRateParams() = ExponentialBAParams(
    0,
    exp(-13.1),
    exp(-13.1),
    0.25,
    0.25,
    0.25,
    -0.8,
    -0.8,
    -0.8,
    -0.38,
)

"""
    DefaultExpBACarryingCapacityParams()

Default temp dependent and allometric parameters (a, b, c, Eₐ) values for carrying capacity.([Meehan, 2006](https://doi.org/10.1890/0012-9658(2006)87%5B1650:EUAAAI%5D2.0.CO%3B2), [Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
DefaultExpBACarryingCapacityParams() =
    ExponentialBAParams(3, nothing, nothing, 0.28, 0.28, 0.28, 0, 0, 0, 0.71)

#### end ####
struct NoTemperatureResponse <: TemperatureResponse end


mutable struct ExponentialBA <: TemperatureResponse
    r::ExponentialBAParams
    x::ExponentialBAParams
    aᵣ::ExponentialBAParams
    hₜ::ExponentialBAParams
    K::ExponentialBAParams
end


function ExponentialBA(
    r = DefaultExpBAGrowthParams(),
    x = DefaultExpBAMetabolismParams(),
    aᵣ = DefaultExpBAAttackRateParams(),
    hₜ = DefaultExpBAHandlingTimeParams(),
    K = DefaultExpBACarryingCapacityParams(),
)
    ExponentialBA(r, x, aᵣ, hₜ, K)
end

#### Type display ####
"""
    Base.show(io::IO, temperature_response::TemperatureResponse)

One line TemperatureResponse display.
"""
function Base.show(io::IO, temperature_response::TemperatureResponse)
    print(io, "$(typeof(temperature_response))")
end

"""
Multiline TemperatureResponse::ExponentialBA display.
"""
function Base.show(io::IO, ::MIME"text/plain", temperature_response::ExponentialBA)
    r = temperature_response.r
    x = temperature_response.x
    aᵣ = temperature_response.aᵣ
    hₜ = temperature_response.hₜ
    K = temperature_response.K
    println(io, "Parameters for ExponentialBA response:")
    println(io, "  r: " * "$r")
    println(io, "  x: " * "$x")
    println(io, "  aᵣ: " * "$aᵣ")
    println(io, "  hₜ: " * "$hₜ")
    println(io, "  K: " * "$K")
end

#### Helper functions to compute temperature dependent rates ####

"""
boltzmann(Ea, T, T0)

Calculates the temperature dependence term of the Boltzmann-Arrhenius equation, normalised to 20C.
"""
function boltzmann(Ea, T; T0 = 293.15)
    k = 8.617e-5
    normalised_T = T0 - T
    denom = k * T0 * T
    return exp(Ea * (normalised_T / denom))
end
"""
Create species parameter vectors for a, b, c of length S (species richness) given the
parameters for the different metabolic classes (aₚ,aᵢ,...).
"""
function exponentialBAparams_to_vec(foodweb::EcologicalNetwork, params::ExponentialBAParams)

    # Test
    validclasses = ["producer", "invertebrate", "ectotherm vertebrate"]
    isclassvalid(class) = class ∈ validclasses
    all(isclassvalid.(foodweb.metabolic_class)) || throw(ArgumentError("Metabolic classes
    should be in $(validclasses)"))

    # Set up
    S = richness(foodweb)
    a, b, c = Vector{Union{Float64,Nothing}}(zeros(S)),
    Vector{Union{Float64,Nothing}}(zeros(S)),
    Vector{Union{Float64,Nothing}}(zeros(S))

    # Fill a
    a[producers(foodweb)] .= params.aₚ
    a[invertebrates(foodweb)] .= params.aᵢ
    a[vertebrates(foodweb)] .= params.aₑ

    # Fill b
    b[producers(foodweb)] .= params.bₚ
    b[invertebrates(foodweb)] .= params.bᵢ
    b[vertebrates(foodweb)] .= params.bₑ

    # Fill c (defined by resource j)
    c[producers(foodweb)] .= params.cₚ
    c[invertebrates(foodweb)] .= params.cᵢ
    c[vertebrates(foodweb)] .= params.cₑ


    (a = a, b = b, c = c, Eₐ = params.Eₐ)
end

#### Main functions to compute temperature dependent biological rates ####

"""
Compute rate vector (one value per species) with temperature dependent scaling. (x, r, K)
"""
function exponentialBA_vector_rate(
    net::EcologicalNetwork,
    T::Real,
    exponentialBAparams::ExponentialBAParams,
)
    params = exponentialBAparams_to_vec(net, exponentialBAparams)
    a, b, Eₐ = params.a, params.b, params.Eₐ
    boltzmann_term = boltzmann(Eₐ, T)
    allometry = []
    for i in eachindex(a)
        if isnothing(a[i])
            push!(allometry, nothing)
        else
            push!(allometry, allometricscale(a[i], b[i], net.M[i]) * boltzmann_term)
        end
    end

    allometry
end

"""
Compute rate natrix (one value per species interaction) with temperature dependent scaling. (aᵣ, hₜ)
"""
function exponentialBA_matrix_rate(
    net::EcologicalNetwork,
    T::Real,
    exponentialBAparams::ExponentialBAParams,
)
    params = exponentialBAparams_to_vec(net, exponentialBAparams)
    a, b, c, Eₐ = params.a, params.b, params.c, params.Eₐ
    consumer_allometry = allometricscale.(a, b, net.M)
    resource_allometry = allometricscale.(1, c, net.M)
    boltzmann_term = boltzmann(Eₐ, T)

    links = findall(x -> x == 1, net.A)
    mat = Float64.(deepcopy(net.A))
    for i in links
        cons = i[1]
        res = i[2]
        mat[cons, res] = consumer_allometry[cons] * resource_allometry[res] * boltzmann_term
    end
    mat
end
#### end ####
