#=
Biological rates
=#

#### Type definiton ####
mutable struct BioRates
    r::Vector{<:Real}
    x::Vector{<:Real}
    y::Vector{<:Real}
    e::SparseMatrixCSC{Float64,Int64}
end
#### end ####

#### Type display ####
"One line BioRates display."
function Base.show(io::IO, b::BioRates)
    print(io, "BioRates(e, r, x, y)")
end

"Multiline FoodWeb display."
function Base.show(io::IO, ::MIME"text/plain", biorates::BioRates)

    # Specify parameters
    e = biorates.e
    r = biorates.r
    x = biorates.x
    y = biorates.y
    S = size(e, 1)

    # Display output
    println(io, "BioRates:")
    println(io, "  e: $(S)x$(S) sparse matrix")
    println(io, "  r: " * vector_to_string(r))
    println(io, "  x: " * vector_to_string(x))
    print(io, "  y: " * vector_to_string(y))
end
#### end ####

#### Constructors containing default parameter value for allometric scaled rates ####
"""
    DefaultGrowthParams()

Default allometric parameters (a, b) values for growth rate (r).

See also [`AllometricParams`](@ref)
"""
DefaultGrowthParams() = AllometricParams(1.0, 0.0, 0.0, -0.25, 0.0, 0.0)

"""
    DefaultMetabolismParams()

Default allometric parameters (a, b) values for metabolic rate (x).

See also [`AllometricParams`](@ref)
"""
DefaultMetabolismParams() = AllometricParams(0, 0.88, 0.314, 0, -0.25, -0.25)

"""
    DefaultMaxConsumptionParams()

Default allometric parameters (a, b) values for max consumption rate (y).

See also [`AllometricParams`](@ref)
"""
DefaultMaxConsumptionParams() = AllometricParams(0.0, 4.0, 8.0, 0.0, 0.0, 0.0)

"""
    AllometricParams(aₚ, aₑ, aᵢ, bₚ, bₑ, bᵢ)

Parameters used to compute allometric rates for different metabolic classes.

The rate R is expressed as follow: ``R = aMᵇ``, where a and b can take different values
depending on the metabolic class of the species. This struct aims at storing these values
of a and b. Specifically:
- aₚ: a for producers
- aₑ: a for ectotherm vertebrates
- aᵢ: a for invertebrates
- bₚ: b for producers
- bₑ: b for ectotherm vertebrates
- bᵢ: b for invertebrates

Default parameters values taken from the literature for certain rates can be accessed by
calling the corresponding function, for:
- growth rate (r) call [`DefaultGrowthParams`](@ref)
- metabolic rate (x) call [`DefaultMetabolismParams`](@ref)
- max consumption rate (y) call [`DefaultMaxConsumptionParams`](@ref)

# Example
```jldoctest
julia> params = AllometricParams(1, 2, 3, 4, 5, 6)
AllometricParams(1, 2, 3, 4, 5, 6)
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

#### Main functions to compute biological rates ####
"""
    BioRates(
        foodweb;
        r = allometric_rate(foodweb, DefaultGrowthParams()),
        x = allometric_rate(foodweb, DefaultMetabolismParams()),
        y = allometric_rate(foodweb, DefaultMaxConsumptionParams())
        )

Compute the biological rates (r, x and y) of each species in the system.

The rates are:
- r: the growth rate
- x: the metabolic rate or metabolic demand
- y: the maximum consumption rate
If no value are provided for the rates, they take default values assuming an allometric
scaling. Custom values can be provided for one or several rates by giving a vector of
length 1 or S (species richness). Moreover, if one want to use allometric scaling
(``R = aMᵇ``) but do not want to use default values for a and b, one can simply call
[`allometric_rate`](@ref) with custom [`AllometricParams`](@ref).

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 1; 0 0]); # sp. 1 "invertebrate", sp. 2 "producer"

julia> BioRates(foodweb) # default
r (growth rate): 0.0, ..., 1.0
x (metabolic rate): 0.314, ..., 0.0
y (max. consumption rate): 8.0, ..., 0.0

julia> BioRates(foodweb; r = [1.0, 1.0]) # specify custom vector for growth rate
r (growth rate): 1.0, ..., 1.0
x (metabolic rate): 0.314, ..., 0.0
y (max. consumption rate): 8.0, ..., 0.0

julia> BioRates(foodweb; x = 2.0) # if single value, fill the rate vector with it
r (growth rate): 0.0, ..., 1.0
x (metabolic rate): 2.0, ..., 2.0
y (max. consumption rate): 8.0, ..., 0.0

julia> custom_params = AllometricParams(3, 0, 0, 0, 0, 0); # use custom allometric params...

julia> BioRates(foodweb; y=allometric_rate(foodweb, custom_params)) # ...with allometric_rate
r (growth rate): 0.0, ..., 1.0
x (metabolic rate): 0.314, ..., 0.0
y (max. consumption rate): 0.0, ..., 3.0
```
"""
function BioRates(
    foodweb::FoodWeb;
    r::Union{Vector{<:Real},<:Real}=allometric_rate(foodweb, DefaultGrowthParams()),
    x::Union{Vector{<:Real},<:Real}=allometric_rate(foodweb, DefaultMetabolismParams()),
    y::Union{Vector{<:Real},<:Real}=allometric_rate(foodweb, DefaultMaxConsumptionParams()),
    e=assimilation_efficiency(foodweb)
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
    size(e) == (S, S) || throw(ArgumentError("e should be of size (S, S) with S the species
        richness"))
    e = sparse(e)

    # Output
    r, x, y = Rates # recover formated rates
    BioRates(r, x, y, e)
end

"Compute rate vector (one value per species) with allometric scaling."
function allometric_rate(
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
