#=
Utility functions for functions in measures 
=#

"""
**Filter simulation timestep**

# Argument

  - solution: the output of `simulate()`
"""
function filter_sim(solution; last::Int64 = 1000)
    @assert last <= length(solution.t)
    return solution[:, end-(last-1):end]
end
