#=
Stressor
=#

#### Type definiton ####
mutable struct Stressor
    addstressor::Bool
    slope::Union{Float64, Vector{Float64}}
    start::Float64
    weights::Vector{Float64}
end
#### end ####

#### Type display ####
"""
One line [`Stressor`](@ref) display.
"""
function Base.show(io::IO, stressor::Stressor)
    if stressor.addstressor == true &&
        print(io, "Stressor(addstressor, slope, start, weights)")
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
        weights = stressor.weights

        println(io, "Stressor:")
        println(io, "  addstressor: $addstressor")
        println(io, "  slope: $slope")    
        println(io, "  start: $start")
        print(io, " weights: $weights")
    else
        println(io, "Stochasticity:")
        print(io, "  Stochasticity not added")
    end
end
#### end ####

"""
Literally all I need here is something to store these inputs that can be passed to ModelParameters:
"""

function Stressor(fw::EcologicalNetwork; addstressor::Bool = false
    ,slope::Union{Float64, Vector{Float64}} = 0.0
    ,start::Float64 = 0.0
    ,weights::Union{Vector{Float64},Nothing} = nothing)

    # Set default to 1.0 - no weighting
    if isnothing(weights)
        weights = ones(length(BEFWM2.producers(fw)))
    end
    slope = repeat([slope], length(BEFWM2.producers(fw))) .* weights
    Stressor(addstressor, slope, start, weights)
     
end