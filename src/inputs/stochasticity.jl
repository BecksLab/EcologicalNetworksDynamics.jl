mutable struct AddStochasticity
    addstochasticity::Bool
    θ::Vector{<:Real}
    μ::Vector{<:Real}
    σe::Vector{<:Real}
    σd::Vector{<:Real}
    stochspecies::Vector{<:Real}
    stochconsumers::Vector{<:Real}
    stochproducers::Vector{<:Real}
    function AddStochasticity(
        addstochasticity,
        θ,
        μ,
        σe,
        σd,
        stochspecies,
        stochconsumers,
        stochproducers,
    )
        new(addstochasticity, θ, μ, σe, σd, stochspecies, stochconsumers, stochproducers)
    end
end

"One line AddStochasticity display."
function Base.show(io::IO, stochasticity::AddStochasticity)
    if stochasticity.addstochasticity == true && length(stochasticity.σe) > 0 && sum(stochasticity.σd) > 0
        print(io, " Environmental and demographic stochasticity added")
    elseif stochasticity.addstochasticity == true && sum(stochasticity.σd) > 0
        print(io, " Demographic stochasticity added")
    elseif stochasticity.addstochasticity == true && length(stochasticity.σe) > 0
        print(io, " Environmental stochasticity added")
    else
        print(io, " Stochasticity not added")
    end
end

"Multiline AddStochasticity display."
function Base.show(io::IO, ::MIME"text/plain", stochasticity::AddStochasticity)
    if stochasticity.addstochasticity == true && length(stochasticity.σe) > 0 && sum(stochasticity.σd) > 0
        println(io, "Stochasticity:")
        println(io, "  Adding stochasticity?: true")
        println(io, "  θ (rate of return to mean): " * vector_to_string(stochasticity.θ))
        println(
            io,
            "  μ (mean of stochastic parameter): " * vector_to_string(stochasticity.μ),
        )
        println(
            io,
            "  σe (environmental noise scaling parameter): " *
            vector_to_string(stochasticity.σe),
        )
        println(
            io,
            "  σd (demographic noise scaling parameter): " *
            vector_to_string(stochasticity.σd),
        )
        print(io, "  Stochastic species: " * vector_to_string(stochasticity.stochspecies))

    elseif stochasticity.addstochasticity == true && sum(stochasticity.σd) > 0
        println(io, "Stochasticity:")
        println(io, "  Adding stochasticity?: true")
        print(
            io,
            "  σd (demographic noise scaling parameter): " *
            vector_to_string(stochasticity.σd),
        )

    elseif stochasticity.addstochasticity == true && length(stochasticity.σe) > 0
        println(io, "Stochasticity:")
        println(io, "  Adding stochasticity?: true")
        println(io, "  θ (rate of return to mean): " * vector_to_string(stochasticity.θ))
        println(
            io,
            "  μ (mean of stochastic parameter): " * vector_to_string(stochasticity.μ),
        )
        println(
            io,
            "  σe (environmental noise scaling parameter): " *
            vector_to_string(stochasticity.σe),
        )
        print(io, "  Stochastic species: " * vector_to_string(stochasticity.stochspecies))

    else
        println(io, "Stochasticity:")
        print(io, "  Stochasticity not added")
    end
end

#=
Returns a vector (species pool) containing species stochasticity can be added to.
Various versions of the function take the target input of different types
=#

#### Potential stochastic species ####

function stochastic_species_pool(foodweb::FoodWeb, target::String)

    # Collect species that match the target input into 'selected_species'

    if target == "producers"
        selected_species = producers(foodweb)

    elseif target == "consumers"
        selected_species = predators(foodweb)

    elseif target == "allspecies"
        selected_species = [1:1:(richness(foodweb));]
    else
        throw(
            ArgumentError(
                "target group not recognised. target can be one of: \n producers, consumers, or allspecies",
            ),
        )
    end

    selected_species
end

function stochastic_species_pool(foodweb::FoodWeb, target::Vector{Int64})

    target
end

function stochastic_species_pool(foodweb::FoodWeb, target::Int64)

    [target]
end

#### end ####

#### Sample from above species pools ####

function sampled_stochastic_species(species_pool, n_species::String)
    # Sample from these selected species to get a vector of length n_species

    if n_species == "all"
        out = species_pool

    elseif n_species == "random"
        if typeof(target) == Int64
            throw(ArgumentError("You can't randomly sample from 1 species"))
        end
        n_species = sample(1:length(species_pool))
        out = sample(species_pool, n_species; replace = false)
    else
        throw(
            ArgumentError(
                "n_species group not recognised. n_species can be one of: \n all, or random",
            ),
        )
    end

end

function sampled_stochastic_species(species_pool, n_species::Int64)

    if n_species > length(species_pool)
        n_species = length(species_pool)
        @warn "n_species greater than number of species. \n Adding stochasticity to all species"
        out = sample(species_pool, n_species; replace = false)
    else # number of species specified by n_species is less than number of potential stochastic species in species_pool
        out = sample(species_pool, n_species; replace = false)
    end
end

#=
Three functions to check the inputted parameters θ, σd & σe
I could make 1 function and loop but that wouldn't provide as clear error messages

All of these parameters need to:
Return an empty vector if addstochasticity = false - no matter the input
If addstochasticity = true...
    No defaults are provided so need some values
    Be all positive floats (note - an integer in a vector of floats is converted into a float automatically)
    Be trimmed or repeated to be the size of stochspecies

edit: σd is edited so that it is either applied to all species or none. Therefore...
    needs an integer or vector of length richness(foodweb) - other lengths not allowed
    still has to be positive
    now defaults to 0.0
=#

function thetacheck(
    stochspecies::Vector{Int64},
    θ::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if isnothing(θ)
        throw(
            ArgumentError("There are no defaults for θ - provide a value or a vector"),
        )
    elseif all(>=(0), θ) == false
        throw(ArgumentError("All values of θ must be positive"))
    end

    if isa(θ, Vector)
        ls = length(stochspecies)
        lθ = length(θ)

        if length(θ) > length(stochspecies)
            @warn "You have provided $lθ θ values and there are $ls stochastic species. \n Using the first $ls values of θ"
            θ = θ[1:length(stochspecies)]
        end

        if length(θ) < length(stochspecies)
            @warn "You have provided $lθ θ values and there are $ls stochastic species. \n Repeating θ until there are $ls values of θ"
            θ = repeat(θ; outer = length(stochspecies))
            θ = θ[1:length(stochspecies)]
        end
    else
        θ = repeat([θ], length(stochspecies))
    end

    return θ
end

function sigmadcheck(
    foodweb,
    addstochasticity::Bool = false,
    σd::Union{Float64,Vector{Float64},Nothing} = nothing
)
    if addstochasticity == false
        σd = Float64[]
    else
        if isnothing(σd)
            σd = repeat([0.0], richness(foodweb))
        elseif all(>=(0), σd) == false
            throw(ArgumentError("All values of σd must be positive"))
        end

        if isa(σd, Vector)
            ns = richness(foodweb) # For the ArgumentError below
            isequal(length(σd), richness(foodweb)) || throw(
                ArgumentError(
                    "σd should be either a single value or a vector of length $ns",
                ),
            )
        else
            σd = repeat([σd], richness(foodweb))
        end
    end

    return σd
end

function sigmaecheck(
    stochspecies::Vector{Int64},
    σe::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if isnothing(σe)
        throw(
            ArgumentError("There are no defaults for σe - provide a value or a vector"),
        )
    elseif all(>=(0), σe) == false
        throw(ArgumentError("All values of σe must be positive"))
    end

    if isa(σe, Vector)
        ls = length(stochspecies)
        lσe = length(σe)

        if length(σe) > length(stochspecies)
            @warn "You have provided $lσe σe values and there are $ls stochastic species. \n Using the first $ls values of σe"
            σe = σe[1:length(stochspecies)]
        end

        if length(σe) < length(stochspecies)
            @warn "You have provided $lσe σe values and there are $ls stochastic species. \n Repeating σe until there are $ls values of σe"
            σe = repeat(σe; outer = length(stochspecies))
            σe = σe[1:length(stochspecies)]
        end
    else
        σe = repeat([σe], length(stochspecies))
    end

    return σe
end



"""
    AddStochasticity(foodweb::FoodWeb; args...)

Creates an object of Type AddStochasticity to hold all parameters related to adding stochasticity into the BEFW. Arguments are as follows:

Arguments required for all types of stochasticity:
- foodweb - a FoodWeb object (MultiplexNetwork objects not compatible)
- addstochasticity - a boolean indicating whether stochasticity will be implemented or not. Defaults to false (i.e. no stochasticity)

Optional arguments required for environmental stochasticity (an Orstein-Uhlenbeck process with a drift term; dxt = θ(μ - xt)dt + σ dWt)
- biorates - a BioRates object to provide μ values for the Ornstein-Uhlenbeck process. Defaults to BioRates(foodweb)
- target - information about which species stochasticity will be added to and is used to produce a pool of potential species
    This may be "producers", "consumers", "allspecies", an integer or vector of integers (relating to the position of species in the interaction matrix)
- n_species - dictates how should the pool of potentially stochastic species be sampled. Defaults to "all"
    This may be "all", "random" or an integer
- θ - a Float64 or Vector{Float64} controlling speed of return to the mean following perturbation (user supplied, no default)
- σe - a Float64 or Vector{Float64} controlling the standard deviation of the noise process for environmental stochasticity (user supplied, no default)

Optional arguments required for demographic stochasticity (a Wiener process scaled by population size)
- σd is the standard deviation of the noise process for demographic stochasticity (user supplied, no default)

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 1 0; 0 0 1; 0 0 0]); # 1 eats 2, 2 eats 3

julia> AddStochasticity(foodweb) # default
Stochasticity:
  Stochasticity not added

julia> AddStochasticity(foodweb, addstochasticity = true, target = "consumers", θ = 0.4, σe = 0.2) # environmental stochasticity
Stochasticity:
  Adding stochasticity?: true
  θ (rate of return to mean): [0.4, 0.4]
  μ (mean of stochastic parameter): [0.314, 0.314]
  σe (environmental noise scaling parameter): [0.2, 0.2]
  Stochastic species: [1, 2]

julia> AddStochasticity(foodweb, addstochasticity = true, σd = 0.1) # demographic stochasticity
Stochasticity:
  Adding stochasticity?: true
  σd (demographic noise scaling parameter): [0.1, 0.1, 0.1]
```
"""
function AddStochasticity(
    foodweb::FoodWeb;
    addstochasticity::Bool = false,
    biorates::Union{BioRates,Nothing} = nothing,
    target::Union{String,Vector{String},Int64,Vector{Int64},Nothing} = nothing,
    n_species::Union{Int64,String,Nothing} = "all",
    θ::Union{Float64,Vector{Float64},Nothing} = nothing,
    σe::Union{Float64,Vector{Float64},Nothing} = nothing,
    σd::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if addstochasticity == true && !isnothing(σe) # environmental stochasticity
        if addstochasticity == true && isnothing(biorates)
            biorates = BioRates(foodweb)
        elseif addstochasticity == true && isnothing(target)
            throw(
                ArgumentError(
                    "There is no default target - choose either producer, consumer, or allspecies",
                ),
            )
        end
        species_pool = stochastic_species_pool(foodweb, target)
        stochspecies = sampled_stochastic_species(species_pool, n_species)
        stochspecies = sort(stochspecies) # For presentation's sake
        stochproducers = intersect(stochspecies, producers(foodweb))
        stochconsumers = intersect(stochspecies, predators(foodweb))

        θ = thetacheck(stochspecies, θ)
        σe = sigmaecheck(stochspecies, σe)

        μ = zeros(length(stochspecies))

        for (i, j) in enumerate(stochspecies)
            if j ∈ producers(foodweb)
                μ[i] = biorates.r[j]
            else
                μ[i] = biorates.x[j]
            end
        end

    else
        θ = Float64[]
        σe = Float64[]
        μ = Float64[]
        stochspecies = Int64[]
        stochproducers = Int64[]
        stochconsumers = Int64[]
    end

    σd = sigmadcheck(foodweb, addstochasticity, σd) # always needed

    return AddStochasticity(
        addstochasticity,
        θ,
        μ,
        σe,
        σd,
        stochspecies,
        stochconsumers,
        stochproducers,
    )
end

"""
    AddStochasticity(network::MultiplexNetwork)

Stochasticity is not currently implemented for multiplex networks. Trying to use one will return an empty object
"""
function AddStochasticity(
    network::MultiplexNetwork
)
    addstochasticity = false
    θ = Float64[]
    μ = Float64[]
    σe = Float64[]
    σd = Float64[]
    stochspecies = Int64[]
    stochconsumers = Int64[]
    stochproducers = Int64[]
    return AddStochasticity(
        addstochasticity,
        θ,
        μ,
        σe,
        σd,
        stochspecies,
        stochconsumers,
        stochproducers,
    )
end