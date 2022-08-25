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
    if stochasticity.addstochasticity == true
        n = length(stochasticity.stochspecies)
        print(io, "Stochasticity added to $n species")
    else
        print(io, "Stochasticity not added")
    end
end

"Multiline AddStochasticity display."
function Base.show(io::IO, ::MIME"text/plain", stochasticity::AddStochasticity)
    if stochasticity.addstochasticity == true
        println(io, " Adding stochasticity?: true")
        println(io, " θ (rate of return to mean): " * vector_to_string(stochasticity.θ))
        println(
            io,
            " μ (mean of stochastic parameter): " * vector_to_string(stochasticity.μ),
        )
        println(
            io,
            " σe (environmental noise scaling parameter): " *
            vector_to_string(stochasticity.σe),
        )
        println(
            io,
            " σd (demographic noise scaling parameter): " *
            vector_to_string(stochasticity.σd),
        )
        print(io, " Stochastic species: " * vector_to_string(stochasticity.stochspecies))

    else
        println(io, "Adding stochasticity?: false")
        println(io, "θ (rate of return to mean): Empty")
        println(io, "μ (mean of stochastic parameter): Empty")
        println(io, "σe (environmental noise scaling parameter): Empty")
        print(io, "σd (demographic noise scaling parameter): Empty")
    end
end

#=
This internal function returns a vector of the species stochasticity will be added to
It needs to be provided with:
 a FoodWeb object
 a list of which species stochasticity will be added to (wherestochasticity)
 - this can be "producers", "consumers", "allspecies", an integer or vector of integers
 how many species in the above group will stochasticity be added to
 - this can be "all", "random" or an integer

There are a lot of ifs here because there are so many options...
=#

#### Potential stochastic species ####

function stochastic_species_pool(FW::FoodWeb, wherestochasticity::String)

    idp = producers(FW)

    # Collect species that match the wherestochasticity input into 'selected_species'

    if wherestochasticity == "producers"
        selected_species = producers(FW)

    elseif wherestochasticity == "consumers"
        selected_species = predators(FW)

    elseif wherestochasticity == "allspecies"
        selected_species = [1:1:(richness(FW));]
    else
        throw(
            ArgumentError(
                "wherestochasticity group not recognised. wherestochasticity can be one of: \n producers, consumers, or allspecies",
            ),
        )
    end

    selected_species
end

function stochastic_species_pool(FW::FoodWeb, wherestochasticity::Vector{Int64})

    wherestochasticity
end

function stochastic_species_pool(FW::FoodWeb, wherestochasticity::Int64)

    [wherestochasticity]
end

#### end ####

#### Sample from above species pools ####

function sampled_stochastic_species(species_pool, nstochasticity::String)
    # Sample from these selected species to get a vector of length nstochasticity

    if nstochasticity == "all"
        out = species_pool

    elseif nstochasticity == "random"
        if typeof(wherestochasticity) == Int64
            throw(ArgumentError("You can't randomly sample from 1 species"))
        end
        nstochasticity = sample(1:length(species_pool))
        out = sample(species_pool, nstochasticity; replace = false)
    else
        throw(
            ArgumentError(
                "nstochasticity group not recognised. nstochasticity can be one of: \n all, or random",
            ),
        )
    end

end

function sampled_stochastic_species(species_pool, nstochasticity::Int64)

    if nstochasticity > length(species_pool)
        nstochasticity = length(species_pool)
        @warn "nstochasticity greater than number of species. \n Adding stochasticity to all species"
        out = sample(species_pool, nstochasticity; replace = false)
    else # number of species specified by nstochasticity is less than number of potential stochastic species in species_pool
        out = sample(species_pool, nstochasticity; replace = false)
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
    needs an integer or vector of length richness(FW) - other lengths not allowed
    still has to be positive
    now defaults to 0.0
=#

function thetacheck(
    stochspecies::Vector{Int64},
    addstochasticity::Bool = false,
    θ::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if addstochasticity == false
        θ = Float64[]
    else
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
    end

    return θ
end

function sigmadcheck(
    FW,
    stochspecies::Vector{Int64},
    addstochasticity::Bool = false,
    σd::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if addstochasticity == false
        σd = Float64[]
    else
        if isnothing(σd)
            σd = repeat([0.0], richness(FW))
        elseif all(>=(0), σd) == false
            throw(ArgumentError("All values of σd must be positive"))
        end

        if isa(σd, Vector)
            ns = richness(FW) # For the ArgumentError below
            isequal(length(σd), richness(FW)) || throw(
                ArgumentError(
                    "σd should be either a single value or a vector of length $ns",
                ),
            )
        else
            σd = repeat([σd], richness(FW))
        end
    end

    return σd
end

function sigmaecheck(
    stochspecies::Vector{Int64},
    addstochasticity::Bool = false,
    σe::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    if addstochasticity == false
        σe = Float64[]
    else
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
    end

    return σe
end



"""
AddStochasticity(FW::FoodWeb, BR::Union{BioRates, Nothing} = nothing; addstochasticity::Bool = false, wherestochasticity::Union{String, Vector{String}, Int64, Vector{Int64}, Nothing} = nothing, nstochasticity::Union{Int64, String, Nothing} = nothing, θ::Union{Float64, Vector{Float64}, Nothing} = nothing, σe::Union{Float64, Vector{Float64}, Nothing} = nothing, σd::Union{Float64, Vector{Float64}, Nothing} = nothing)

Creates an object of Type AddStochasticity to hold all parameters related to adding stochasticity into the BEFW

- FW is a FoodWeb object
- BR is a BioRates object
- addstochasticity is a boolean indicating whether stochasticity will be added or not - if true the following arguments will need to be supplied; there are no defaults
- wherestochasticity contains information about which species stochasticity will be added to
    This may be "producers", "consumers", "allspecies", or an integer or vector of integers (relating to the position of species in the interaction matrix)
- nstochasticity provides the number of species stochasticity will be added to
    This may be "all", "random" or a number

Environmental stochasticity is added using an Orstein-Uhlenbeck process with a drift term; dxt = θ(μ - xt)dt + σ dWt
- θ controls speed of return to the mean following perturbation
- μ is the mean value of the stochastic parameter (taken from BioRates)
- σe is the standard deviation of the noise process for environmental stochasticity
- σd is the standard deviation of the noise process for demographic stochasticity
"""
function AddStochasticity(
    FW::FoodWeb,
    BR::Union{BioRates,Nothing} = nothing;
    addstochasticity::Bool = false,
    wherestochasticity::Union{String,Vector{String},Int64,Vector{Int64},Nothing} = nothing,
    nstochasticity::Union{Int64,String,Nothing} = nothing,
    θ::Union{Float64,Vector{Float64},Nothing} = nothing,
    σe::Union{Float64,Vector{Float64},Nothing} = nothing,
    σd::Union{Float64,Vector{Float64},Nothing} = nothing,
)

    # Step 1: Generate a vector containing the stochastic species

    if addstochasticity == true && isnothing(BR)
        throw(ArgumentError("If adding stochasticity please provide a BioRates object"))
    elseif addstochasticity == true && isnothing(wherestochasticity)
        throw(
            ArgumentError(
                "There are no defaults for wherestochasticity - provide a value or a vector",
            ),
        )
    elseif addstochasticity == true && isnothing(nstochasticity)
        throw(ArgumentError("There are no defaults for nstochasticity - provide a value"))
    end

    stochspecies = Int64[]

    if addstochasticity == true
        species_pool = stochastic_species_pool(FW, wherestochasticity)
        stochspecies = sampled_stochastic_species(species_pool, nstochasticity)
    else
        stochspecies = Int64[]
    end

    if length(stochspecies) > 1 # stochspecies is Vector{Any}, I want it Vector{Int64}
        stochspecies = convert(Vector{Int64}, stochspecies)
    elseif length(stochspecies) == 1 && typeof(stochspecies) != Vector{Int64}
        stochspecies = [stochspecies]
    end
    stochspecies = sort(stochspecies) # For presentation's sake

    # Step 2: Use the vector of stochastic species to generate the vectors for stochastic parameters

    θ = thetacheck(stochspecies, addstochasticity, θ)
    σd = sigmadcheck(FW, stochspecies, addstochasticity, σd)
    σe = sigmaecheck(stochspecies, addstochasticity, σe)


    μ = zeros(length(stochspecies))

    if isnothing(BR)
        μ = Float64[]
    else
        for (i, j) in enumerate(stochspecies)
            if j ∈ producers(FW)
                μ[i] = BR.r[j]
            else
                μ[i] = BR.x[j]
            end
        end
    end

    #Step 3: Make vectors of stochconsumers & stochproducers

    stochconsumers = Int64[]
    stochproducers = Int64[]

    if addstochasticity == true
        for i in stochspecies
            if i ∈ producers(FW)
                push!(stochproducers, i)
            else
                push!(stochconsumers, i)
            end
        end
    end

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
