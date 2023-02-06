#=
Temperature dependent rates
=#

abstract type TemperatureResponse end

raw"""
    ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

Parameters used to compute temperature dependent rates
for different metabolic classes
using a Exponential Boltzmann Arrhenius method of temperature dependence.
The rate R is expressed as follow:
``R = a {M_i}^b {M_j}^c e^{E_a\frac{(T - T_0)}{k T_0 T}}``,
where `a`, `b` and `c` can take different values
depending on the metabolic class of the species,
although by default these do not vary as such.
Growth and metabolic rate scale allometrically solely with species `i`,
whereas feeding rates (`y`, `B0`, `Th`, `ar`)
also depend on the body mass of resource species `j`.
- `a` is the intercept
- b is the allometric exponent of the resource
- c is the allometric exponent of the consumer

This struct aims at storing these values of `a`, `b` & `c`
and the activation energy `Eₐ` for each rate. Specifically:

    | parameter                      | producers | ectotherm vertebrates | invertebrates |
    | ------------------------------ | --------- | --------------------- | ------------- |
    | intercept                      | aₚ        | aₑ                    | aᵢ            |
    | allometric exponent (resource) | bₚ        | bₑ                    | bᵢ            |
    | allometric exponent (consumer) | cₚ        | cₑ                    | cᵢ            |
    | activation energy              | >         | >                     | Eₐ            |

Default parameters values taken from the literature for certain rates can be accessed by
calling the corresponding function, for:

- Exponential Boltzmann Arrhenius growth rate (`r`),
  call [`exp_ba_growth()`](@ref)
- Exponential Boltzmann Arrhenius metabolic rate (`x`),
  call [`exp_ba_metabolism()`](@ref)
- Exponential Boltzmann Arrhenius handling time (`hₜ`),
  call [`exp_ba_handling_time()`](@ref)
- Exponential Boltzmann Arrhenius attack rate (`aᵣ`),
  call [`exp_ba_attack_rate()`](@ref)
- Exponential Boltzmann Arrhenius carrying capacity (`K`),
  call [`exp_ba_carrying_capacity()`](@ref)
"""
struct ExponentialBAParams
    aₚ::Union{Float64,Nothing}
    aₑ::Union{Float64,Nothing}
    aᵢ::Union{Float64,Nothing}
    bₚ::Float64
    bₑ::Float64
    bᵢ::Float64
    cₚ::Float64
    cₑ::Float64
    cᵢ::Float64
    Eₐ::Float64
end


#### Constructors containing default parameter value for temperature scaled rates ####
"""
    exp_ba_growth()

Default temperature-dependent and allometric parameters (`a`, `b`, `c`, `Eₐ`) values
for growth rate (`r`).
([Savage et al., 2004](https://doi.org/10.1086/381872),
[Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
exp_ba_growth(;
    aₚ = exp(-15.68),
    aₑ = 0,
    aᵢ = 0,
    bₚ = -0.25,
    bₑ = -0.25,
    bᵢ = -0.25,
    cₚ = 0,
    cₑ = 0,
    cᵢ = 0,
    Eₐ = -0.84,
) = ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

"""
    exp_ba_metabolism()

Default temperature-dependent and allometric parameters (`a`, `b`, `c`, `Eₐ`) values
for metabolic rate (`x`).
([Ehnes et al., 2011](https://doi.org/10.1111/j.1461-0248.2011.01660.x),
[Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
exp_ba_metabolism(;
    aₚ = 0,
    aₑ = exp(-16.54),
    aᵢ = exp(-16.54),
    bₚ = -0.31,
    bₑ = -0.31,
    bᵢ = -0.31,
    cₚ = 0,
    cₑ = 0,
    cᵢ = 0,
    Eₐ = -0.69,
) = ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

"""
    exp_ba_handling_time()

Default temperature-dependent and allometric parameters (`a`, `b`, `c`, `Eₐ`) values
for handling time (`hₜ`).
([Rall et al., 2012](https://doi.org/10.1098/rstb.2012.0242),
[Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
exp_ba_handling_time(;
    aₚ = 0,
    aₑ = exp(9.66),
    aᵢ = exp(9.66),
    bₚ = -0.45,
    bₑ = -0.45,
    bᵢ = -0.45,
    cₚ = 0.47,
    cₑ = 0.47,
    cᵢ = 0.47,
    Eₐ = 0.26,
) = ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

"""
    exp_ba_attack_rate()

Default temperature-dependent and allometric parameters (`a`, `b`, `c`, `Eₐ`) values
for attack rate (aᵣ).
([Rall et al., 2012](https://doi.org/10.1098/rstb.2012.0242),
[Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
exp_ba_attack_rate(;
    aₚ = 0,
    aₑ = exp(-13.1),
    aᵢ = exp(-13.1),
    bₚ = 0.25,
    bₑ = 0.25,
    bᵢ = 0.25,
    cₚ = -0.8,
    cₑ = -0.8,
    cᵢ = -0.8,
    Eₐ = -0.38,
) = ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)

"""
    exp_ba_carrying_capacity()

Default temperature-dependent and allometric parameters (`a`, `b`, `c`, `Eₐ`) values
for carrying capacity.
([Meehan, 2006](https://doi.org/10.1890/0012-9658(2006)87%5B1650:EUAAAI%5D2.0.CO%3B2),
[Binzer et al., 2016](https://doi.org/10.1111/gcb.13086))
"""
exp_ba_carrying_capacity(;
    aₚ = 3,
    aₑ = nothing,
    aᵢ = nothing,
    bₚ = 0.28,
    bₑ = 0.28,
    bᵢ = 0.28,
    cₚ = 0,
    cₑ = 0,
    cᵢ = 0,
    Eₐ = 0.71,
) = ExponentialBAParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ, cₚ, cₑ, cᵢ, Eₐ)
#### end ####

# Degenerated temperature response with no effect.
struct NoTemperatureResponse <: TemperatureResponse end

# Exponential Boltzmann-Arrhenius temperature response.
mutable struct ExponentialBA <: TemperatureResponse
    r::ExponentialBAParams
    x::ExponentialBAParams
    aᵣ::ExponentialBAParams
    hₜ::ExponentialBAParams
    K::ExponentialBAParams
end

"""
    ExponentialBA()

Generates the default parameters used to calculate temperature dependent rates
using the exponential Boltzmann-Arrhenius method
"""
function ExponentialBA(;
    r = exp_ba_growth(),
    x = exp_ba_metabolism(),
    aᵣ = exp_ba_attack_rate(),
    hₜ = exp_ba_handling_time(),
    K = exp_ba_carrying_capacity(),
)
    ExponentialBA(r, x, aᵣ, hₜ, K)
end

#### Type display ####
"""
    Base.show(io::IO, temperature_response::TemperatureResponse)

One-line TemperatureResponse display.
"""
function Base.show(io::IO, temperature_response::TemperatureResponse)
    print(io, "$(typeof(temperature_response))")
end

"""
Multiline TemperatureResponse::ExponentialBA display.
"""
function Base.show(io::IO, ::MIME"text/plain", temperature_response::ExponentialBA)
    (; r, x, aᵣ, hₜ, K) = temperature_response
    println(io, "Parameters for ExponentialBA response:")
    println(io, "  r: $r")
    println(io, "  x: $x")
    println(io, "  aᵣ: $aᵣ")
    println(io, "  hₜ: $hₜ")
    println(io, "  K: $K")
end

#### Helper functions to compute temperature dependent rates ####

"""
    boltzmann(Ea, T, T0)

Calculates the temperature dependence term of the Boltzmann-Arrhenius equation,
normalised to 20°C.
"""
function boltzmann(Ea, T; T0 = 293.15)
    k = 8.617e-5
    normalised_T = T0 - T
    denom = k * T0 * T
    exp(Ea * (normalised_T / denom))
end

"""
    exp_ba_params_to_vec(foodweb, ExponentialBAparams)

Create species parameter vectors for `a`, `b`, `c`
of length `S` (species richness)
given the parameters for the different metabolic classes (`aₚ`, `a`, ...).
"""
function exp_ba_params_to_vec(foodweb::EcologicalNetwork, temp_params::ExponentialBAParams)

    # Test
    validclasses = ["producer", "invertebrate", "ectotherm vertebrate"]
    isclassvalid(class) = class ∈ validclasses
    all(isclassvalid.(foodweb.metabolic_class)) ||
        throw(ArgumentError("Metabolic classes should be in $(validclasses)"))

    # Set up
    S = richness(foodweb)
    a, b, c = Vector{Any}(zeros(S)), Vector{Any}(zeros(S)), Vector{Any}(zeros(S))

    # Fill a
    a[producers(foodweb)] .= temp_params.aₚ
    a[invertebrates(foodweb)] .= temp_params.aᵢ
    a[vertebrates(foodweb)] .= temp_params.aₑ

    # Fill b
    b[producers(foodweb)] .= temp_params.bₚ
    b[invertebrates(foodweb)] .= temp_params.bᵢ
    b[vertebrates(foodweb)] .= temp_params.bₑ

    # Fill c (defined by resource j)
    c[producers(foodweb)] .= temp_params.cₚ
    c[invertebrates(foodweb)] .= temp_params.cᵢ
    c[vertebrates(foodweb)] .= temp_params.cₑ


    (a = a, b = b, c = c, Eₐ = temp_params.Eₐ)
end

#### Main functions to compute temperature dependent biological rates ####

"""
    exp_ba_vector_rate(net, T ExponentialBAParams)

Compute rate vector (one value per species)
with temperature dependent scaling,
given the parameters stored in an ExponentialBAParams struct `(x, r, K)`.

```jldoctest
julia> fw = FoodWeb([0 0; 1 0])
       p = exp_ba_growth()
       exp_ba_vector_rate(fw, 303.15, p) ≈ [4.6414071636920824e-7, 0.0]
true
```
"""
function exp_ba_vector_rate(net, T, exponentialBAparams)
    temp_params = exp_ba_params_to_vec(net, exponentialBAparams)
    (; a, b, Eₐ) = temp_params
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
    exp_ba_matrix_rate(net, T, exponentialBAparams)

Compute rate matrix (one value per species interaction)
with temperature dependent scaling,
given the parameters stored in an ExponentialBAParams struct `(aᵣ, hₜ)`.

```jldoctest
julia> fw = FoodWeb([0 0; 1 0]);
       p = exp_ba_attack_rate();
       exp_ba_matrix_rate(fw, 303.15, p)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅           ⋅
 3.35932e-6   ⋅
```
"""
function exp_ba_matrix_rate(net, T, exponentialBAparams)
    temp_params = exp_ba_params_to_vec(net, exponentialBAparams)
    (; a, b, c, Eₐ) = temp_params
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
