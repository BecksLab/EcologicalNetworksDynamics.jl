#=
Stressor
=#

#### Type definiton ####
mutable struct Stressor
    addstressor::Bool
    slope::Float64
    start::Float64
end
#### end ####

#### Type display ####
"""
One line [`Stressor`](@ref) display.
"""
Base.show(io::IO, s::Stressor) = print(io, "Stressor(addstressor, slope, start)")

"""
Multiline [`Stressor`](@ref) display.
"""
function Base.show(io::IO, ::MIME"text/plain", stressor::Stressor)
    addstressor = stressor.addstressor
    slope = stressor.slope
    start = stressor.start

    println(io, "Stressor:")
    println(io, "  addstressor: $addstressor")
    println(io, "  slope: $slope")    
    print(io, "  start: $start")

end
#### end ####

"""
Literally all I need here is something to store these inputs that can be passed to ModelParameters:
"""

function Stressor(; addstressor::Bool = false
    ,slope::Float64 = 0.0
    ,start::Float64 = 0.0)
    
    Stressor(addstressor, slope, start)
     
end