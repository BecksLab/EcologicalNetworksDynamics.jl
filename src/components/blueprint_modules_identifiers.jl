# Stupid shenanigans to trick JuliaLS into correctly finding references.
# and not clutter further code with "missing reference" warnings.
# All this code does nothing when actually executed.
# Its sole purpose is to solve these incorrect lints.

include("./macros_keywords.jl")

# https://discourse.julialang.org/t/lsp-missing-reference-woes/98231/11?u=iago-lito
@static if (false)
    include("../GraphDataInputs/GraphDataInputs.jl")
    using .GraphDataInputs
end

@static if (false)
    include("../AliasingDicts/AliasingDicts.jl")
    using .AliasingDicts
end

@static if (false)
    include("../kwargs_helpers.jl")
    using .KwargsHelpers
end

include("./allometry_identifiers.jl")
