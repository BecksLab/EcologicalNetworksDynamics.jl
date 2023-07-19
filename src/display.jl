module Display

using SparseArrays

# Elide elements from vector if too numerous.
function join_elided(vec, args...; max = 5, kwargs...)
    vec = if length(vec) > max
        a, b = vec[1:max-1], vec[end:end]
        a, b = dot_display.((a, b))
        vcat(a, "...", b)
    else
        dot_display(vec)
    end
    join(vec, args...; kwargs...)
end
export join_elided

# Special-case sparse vectors so it special-displays missing values.
dot_display(vec) = repr.(vec)
function dot_display(vec::AbstractSparseVector)
    res = repeat(["·"], length(vec))
    nzi, nzv = findnz(vec)
    res[nzi] = repr.(nzv)
    res
end

end
