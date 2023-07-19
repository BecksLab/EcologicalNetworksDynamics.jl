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

Value = EcologicalNetworksDynamics.InnerParms # To make @sysfails work.
import ..Main: @viewfails, @sysfails, @argfails

const EN = EcologicalNetworksDynamics

# Many small similar components tests files, although they easily diverge.
only = [] # Only run these if specified.
for subfolder in ["./data_components", "./code_components"]
    if isempty(only)
        for (folder, _, files) in walkdir(joinpath(dirname(@__FILE__), subfolder))
            for file in files
                path = joinpath(folder, file)
                if !endswith(path, ".jl")
                    continue
                end
                include(path)
            end
        end
    else
        for file in only
            include(joinpath(subfolder, file))
        end
    end
end

end
