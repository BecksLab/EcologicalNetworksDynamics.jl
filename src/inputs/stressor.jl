#=
Stressor
=#

#### Type definiton ####
mutable struct Stressor
    addstressor::Bool
    slope::Union{Float64, Vector{Float64}}
    start::Float64
    step_length::Int64
    weights::Vector{Float64}
    target_trophic_level::Union{String, Int64}
    stressed_species::Vector{Int64}
    base_rate::Vector{Float64}
end
#### end ####

#### Type display ####
"""
One line [`Stressor`](@ref) display.
"""
function Base.show(io::IO, stressor::Stressor)
    if stressor.addstressor == true
        print(io, "Stressor(addstressor, slope, start, weights, target_trophic_level)")
    else
        print(io, "Stressor not added")
    end
end

"""
Multiline [`Stressor`](@ref) display.
"""
function Base.show(io::IO, ::MIME"text/plain", stressor::Stressor)
    if stressor.addstressor == true
        addstressor = stressor.addstressor
        slope = stressor.slope
        start = stressor.start
        step_length = stressor.step_length
        weights = stressor.weights
        target_trophic_level = stressor.target_trophic_level

        println(io, "Stressor:")
        println(io, "  addstressor: $addstressor")
        println(io, "  slope: $slope")    
        println(io, "  start: $start")
        println(io, "  step length: $step_length ")
        println(io, " weights: $weights")
        print(io, " target trophic level: $target_trophic_level")
    else
        println(io, "Stressor:")
        print(io, "  Stressor not added")
    end
end
#### end ####

"""
Literally all I need here is something to store these inputs that can be passed to ModelParameters:
"""

function Stressor(fw::EcologicalNetwork
    ;addstressor::Bool = false
    ,biorates::Union{BioRates,Nothing} = nothing
    ,slope::Union{Float64, Vector{Float64}} = 0.0
    ,start::Float64 = 0.0
    ,step_length::Int64 = 1
    ,weights::Union{Vector{Float64},Nothing} = nothing
    ,target_trophic_level::Union{String, Int64} = "producers"
    ,sample_size::Union{Int64,Nothing} = nothing)

    isnothing(biorates) ? biorates = BioRates(fw) : nothing

    if target_trophic_level == "producers"

        stressed_species = BEFWM2.producers(fw)

        if !isnothing(sample_size)
            stressed_species = sample(stressed_species, sample_size, replace = false)
        end

        # Set default to 1.0 - no weighting
        if isnothing(weights)
            weights = ones(length(stressed_species))
        end
        slope = repeat([slope], length(stressed_species)) .* weights

        base_rate = biorates.r[stressed_species]

    else
        stressed_species = findall(x -> x == target_trophic_level, ceil.(trophic_levels(fw)))

        if !isnothing(sample_size)
            stressed_species = sample(stressed_species, sample_size, replace = false)
        end

        if isnothing(weights)
            weights = ones(length(stressed_species))
        end
        slope = repeat([slope], length(stressed_species)) .* weights

        base_rate = biorates.x[stressed_species]

    end

    Stressor(addstressor, slope, start, step_length, weights, target_trophic_level, stressed_species, base_rate)
     
end