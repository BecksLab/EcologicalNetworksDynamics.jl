#=
Biological rates
=#

#### Type definiton ####
mutable struct BioRates
    d::Vector{<:Real}
    r::Vector{<:Real}
    x::Vector{<:Real}
    y::Vector{<:Real}
    e::SparseMatrixCSC{Float64,Int64}
end
#### end ####

#### Type display ####
"""
One line [`BioRates`](@ref) display.
"""
Base.show(io::IO, b::BioRates) = print(io, "BioRates(d, r, x, y, e)")

"""
Multiline [`BioRates`](@ref) display.
"""
function Base.show(io::IO, ::MIME"text/plain", biorates::BioRates)
    d = biorates.d
    r = biorates.r
    x = biorates.x
    y = biorates.y
    e = biorates.e
    println(io, "BioRates:")
    println(io, "  d: " * vector_to_string(d))
    println(io, "  r: " * vector_to_string(r))
    println(io, "  x: " * vector_to_string(x))
    println(io, "  y: " * vector_to_string(y))
    print(io, "  e: $(size(e)) sparse matrix")
end
#### end ####

#### Constructors containing default parameter value for allometric scaled rates ####
"""
    DefaultMortalityParams(aₚ = 0.0138, aₑ = 0.088, aᵢ = 0.0314,
                       bₚ = -0.25, bₑ = -0.25, bᵢ = -0.25)

Default allometric parameters (a, b) values for mortality rate (d). The intercepts are
simply one tenth of the metabolic loss allometric intercepts (a) as in Miele et al. (2016)
(see [`DefaultMetabolismParams`](@ref)).

# Reference

Miele, V., Guill, C., Ramos-Jiliberto, R., & Kéfi, S. (2019). Non-trophic interactions
strengthen the diversity—Functioning relationship in an ecological bioenergetic network
model. PLOS Computational Biology, 15(8), e1007269.
https://doi.org/10.1371/journal.pcbi.1007269

See also [`AllometricParams`](@ref)
"""
DefaultMortalityParams(aₚ = 0.0138, aₑ = 0.088, aᵢ = 0.0314,
                       bₚ = -0.25, bₑ = -0.25, bᵢ = -0.25) = AllometricParams(aₚ, aₑ, aᵢ,
                                                                              bₚ, bₑ, bᵢ)

"""
    DefaultGrowthParams()

Default allometric parameters (a, b) values for growth rate (r).

See also [`AllometricParams`](@ref)
"""
DefaultGrowthParams() = AllometricParams(1.0, 0.0, 0.0, -0.25, 0.0, 0.0)

"""
    DefaultMetabolismParams(aₚ = 0, aₑ = 0.88, aᵢ = 0.314,
                        bₚ = 0, bₑ = -0.25, bᵢ = -0.25)



Default allometric parameters (a, b) values to compute metabolic rates of consumers (x). The
intercept values were taken from Brose et al. (2006). The allometric parameters for
producers (aₚ, bₚ) are fixed to 0.

# Reference

Brose, U., Williams, R. J., & Martinez, N. D. (2006). Allometric scaling enhances stability
in complex food webs. Ecology Letters, 9(11), 1228‑1236.
https://doi.org/10.1111/j.1461-0248.2006.00978.x


See also [`AllometricParams`](@ref)
"""
DefaultMetabolismParams(aₚ = 0, aₑ = 0.88, aᵢ = 0.314,
                        bₚ = 0, bₑ = -0.25, bᵢ = -0.25) = AllometricParams(aₚ, aₑ, aᵢ,
                                                                          bₚ, bₑ, bᵢ)


"""
    DefaultMaxConsumptionParams(aₚ = 0.0, aₑ = 4.0, aᵢ = 8.0,
                            bₚ = 0.0, bₑ = 0.0, bᵢ = 0.0)

Default allometric parameters (a, b) values to compute maximum consumption rates of
consumers (y). The maximum consumption rates do not scale with bodysize, i.e., all b
parameters are equal to 0. The intercept values were taken from Brose et al. (2006). The
allometric intercept for producers (aₚ) is fixed to 0.

# Reference

Brose, U., Williams, R. J., & Martinez, N. D. (2006). Allometric scaling enhances stability
in complex food webs. Ecology Letters, 9(11), 1228‑1236.
https://doi.org/10.1111/j.1461-0248.2006.00978.x

See also [`AllometricParams`](@ref)
"""
DefaultMaxConsumptionParams(aₚ = 0.0, aₑ = 4.0, aᵢ = 8.0,
                            bₚ = 0.0, bₑ = 0.0, bᵢ = 0.0) = AllometricParams(aₚ, aₑ, aᵢ,
                                                                          bₚ, bₑ, bᵢ)

"""
    AllometricParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ)

Parameters used to compute metabolic rates according to allometric relationships according
to three metabolic classes, i.e. producers, invertebrates, and ectotherm vertebrates.

Each rate R is computed as with allometric relationship with bodymass : ``R = aMᵇ``, where a
and b are respectively the intercept and the slope of this relationship. a and b can take
different values depending on the metabolic class of the species. The indices of a and b (ₚ,
ₑ, ᵢ) correspond to the different metabolic classes:

  - ₚ: producers
  - ₑ: ectotherm vertebrates
  - ᵢ: invertebrates

Default parameters values taken from the literature for certain rates can be accessed by
calling the corresponding function, i.e. for:

  - growth rate (r) call [`DefaultGrowthParams`](@ref)
  - metabolic rate (x) call [`DefaultMetabolismParams`](@ref)
  - max consumption rate (y) call [`DefaultMaxConsumptionParams`](@ref)

# Example

```jldoctest
julia> params = AllometricParams(1, 2, 3, 4, 5, 6)
AllometricParams(aₚ=1, aₑ=2, aᵢ=3, bₚ=4, bₑ=5, bᵢ=6)

julia> params.aₚ
1

julia> params.aₑ
2
```
"""
struct AllometricParams
    aₚ::Real
    aₑ::Real
    aᵢ::Real
    bₚ::Real
    bₑ::Real
    bᵢ::Real
end
#### end ####

#### Type display ####
function Base.show(io::IO, params::AllometricParams)
    aₚ, aₑ, aᵢ = params.aₚ, params.aₑ, params.aᵢ
    bₚ, bₑ, bᵢ = params.bₚ, params.bₑ, params.bᵢ
    print(io, "AllometricParams(aₚ=$aₚ, aₑ=$aₑ, aᵢ=$aᵢ, bₚ=$bₚ, bₑ=$bₑ, bᵢ=$bᵢ)")
end
#### end ####

#### Main functions to compute biological rates ####
"""
    BioRates(
        network::EcologicalNetwork;
        d = allometric_rate(foodweb, DefaultMortalityParams()),
        r = allometric_rate(foodweb, DefaultGrowthParams()),
        x = allometric_rate(foodweb, DefaultMetabolismParams()),
        y = allometric_rate(foodweb, DefaultMaxConsumptionParams()),
        )

Compute the biological rates (r, x, y and e) of each species in the system.

The rates are:

  - d: the natural mortality rate
  - r: the growth rate
  - x: the metabolic rate or metabolic demand
  - y: the maximum consumption rate
  - e: the assimilation efficiency
    If no value are provided for the rates, they take default values assuming an allometric
    scaling. Custom values can be provided for one or several rates by giving a vector of
    length 1 or S (species richness). Moreover, if one want to use allometric scaling
    (``R = aMᵇ``) but do not want to use default values for a and b, one can simply call
    [`allometric_rate`](@ref) with custom [`AllometricParams`](@ref).

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 1; 0 0]); # sp. 1 "invertebrate", sp. 2 "producer"

julia> BioRates(foodweb) # default
BioRates:
  d: [0.0, 0.0]
  r: [0.0, 1.0]
  x: [0.314, 0.0]
  y: [8.0, 0.0]
  e: (2, 2) sparse matrix

julia> BioRates(foodweb; r = [1.0, 1.0]) # specify custom vector for growth rate
BioRates:
  d: [0.0, 0.0]
  r: [1.0, 1.0]
  x: [0.314, 0.0]
  y: [8.0, 0.0]
  e: (2, 2) sparse matrix

julia> BioRates(foodweb; x = 2.0) # if single value, fill the rate vector with it
BioRates:
  d: [0.0, 0.0]
  r: [0.0, 1.0]
  x: [2.0, 2.0]
  y: [8.0, 0.0]
  e: (2, 2) sparse matrix

julia> custom_params = AllometricParams(3, 0, 0, 0, 0, 0); # use custom allometric params...

julia> BioRates(foodweb; y = allometric_rate(foodweb, custom_params)) # ...with allometric_rate
BioRates:
  d: [0.0, 0.0]
  r: [0.0, 1.0]
  x: [0.314, 0.0]
  y: [0.0, 3.0]
  e: (2, 2) sparse matrix
```
"""
function BioRates(
    network::EcologicalNetwork;
    d::Union{Vector{<:Real},<:Real} = zeros(richness(network)),
    r::Union{Vector{<:Real},<:Real} = allometric_rate(network, DefaultGrowthParams()),
    x::Union{Vector{<:Real},<:Real} = allometric_rate(network, DefaultMetabolismParams()),
    y::Union{Vector{<:Real},<:Real} = allometric_rate(
        network,
        DefaultMaxConsumptionParams(),
    ),
    e = efficiency(network),
)
    S = richness(network)
    rate_list = [d, r, x, y]

    # Perform sanity checks and vectorize rate if necessary
    for (i, rate) in enumerate(rate_list)
        isa(rate, Real) ? (rate_list[i] = fill(rate, S)) :
        @check_equal_richness length(rate) S
    end
    @check_size_is_richness² e S

    # Output
    d, r, x, y = rate_list
    BioRates(d, r, x, y, e)
end

"""
Compute rate vector (one value per species) with allometric scaling.
"""
function allometric_rate(net::EcologicalNetwork, allometricparams::AllometricParams)
    params = allometricparams_to_vec(net, allometricparams)
    a, b = params.a, params.b
    allometricscale.(a, b, net.M)
end
#### end ####

#### Helper functions to compute allometric rates ####
"""
Allometric scaling: parameter expressed as a power law of body-mass (M).
"""
function allometricscale(a, b, M)
    (isnothing(a) || isnothing(b)) && return nothing
    a * M^b
end

"""
Create species parameter vectors for a, b of length S (species richness) given the
allometric parameters for the different metabolic classes (aₚ,aᵢ,...).
"""
function allometricparams_to_vec(net::EcologicalNetwork, params::AllometricParams)

    # Test
    validclasses = ["producer", "invertebrate", "ectotherm vertebrate"]
    isclassvalid(class) = class ∈ validclasses
    all(isclassvalid.(net.metabolic_class)) || throw(ArgumentError("Metabolic classes
        should be in $(validclasses)"))

    # Set up
    S = richness(net)
    a, b = zeros(S), zeros(S)

    # Fill allometric parameters (a & b) for each metabolic class
    a[producers(net)] .= params.aₚ
    a[invertebrates(net)] .= params.aᵢ
    a[vertebrates(net)] .= params.aₑ
    b[producers(net)] .= params.bₚ
    b[invertebrates(net)] .= params.bᵢ
    b[vertebrates(net)] .= params.bₑ

    (a = a, b = b)
end
#### end ####
