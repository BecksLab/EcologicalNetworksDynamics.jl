module TestFramework

# Raise the hack flag to test macros within @testset local scopes.
using EcologicalNetworksDynamics.Framework
Framework.LOCAL_MACROCALLS = true

# Run all numbered -.jl files we can find by default, except the current one.
only = [
    # HERE (2024-08-02): all main framework logic has been refactored,
    # now the tests need to pass again.. but I need to stop for a month or so :'(
    "./01-regular_use.jl",
    "./02-blueprint_macro.jl",
    "./03-component_macro.jl",
    "./04-conflicts_macro.jl",
] # Unless some files are specified here, in which case only run these.
if isempty(only)
    for (folder, _, files) in walkdir(dirname(@__FILE__))
        for file in files
            path = joinpath(folder, file)
            if !endswith(path, ".jl") ||
               (abspath(path) == @__FILE__) ||
               !startswith(basename(path), r"[0-9]")
                continue
            end
            include(path)
        end
    end
else
    for file in only
        include(file)
    end
end

Framework.LOCAL_MACROCALLS = false

end
