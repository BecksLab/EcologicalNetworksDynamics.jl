# Test every component behaviour/views specificities.
# Try not to repeat tests already covered by the view/input tests,
# and in general tests covering similar inner calls
# to @component/@method/@expose_data macros/@kwargs_helpers.

module TestComponents

using EcologicalNetworksDynamics
using SparseArrays
using OrderedCollections
using Random
using Test

using ..TestUser

const EN = EcologicalNetworksDynamics
import .EN: WriteError

# Many small similar components tests files, although they easily diverge.
only = [
    "./data_components/species.jl"
    "./data_components/foodweb.jl"
    "./data_components/body_mass.jl"
    "./data_components/metabolic_class.jl"
    "./data_components/temperature.jl"
    "./data_components/hill_exponent.jl"
] # Only run these if specified.
if isempty(only)
    for subfolder in ["./data_components", "./code_components"]
        for (folder, _, files) in walkdir(joinpath(dirname(@__FILE__), subfolder))
            for file in files
                path = joinpath(folder, file)
                if !endswith(path, ".jl")
                    continue
                end
                include(path)
            end
        end
    end
else
    for file in only
        include(file)
    end
end

end
