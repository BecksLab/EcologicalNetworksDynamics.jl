module TestAnalysis

using EcologicalNetworksDynamics
using Random
using Test

import ..Main: @argfails

const EN = EcologicalNetworksDynamics

# Many small similar components tests files, although they easily diverge.
only = [] # Only run these if specified.
for subfolder in ["./analysis"]
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
