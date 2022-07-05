#### Macros ####
"Check that `var` is lower or equal than `max`."
macro check_lower_than(var, max)
    :(
        if $(esc(var)) > $max
            line1 = $(string(var)) * " should be lower or equal to $($max).\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) > $($max)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

"Check that `var` is greater or equal than `min`."
macro check_greater_than(var, min)
    :(
        if $(esc(var)) < $min
            line1 = $(string(var)) * " should be greater or equal to $($min).\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) < $($min)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

"Check that `var` is between `min` and `max` (bounds included)."
macro check_between(var, min, max)
    :(
        if !($min <= $(esc(var)) <= $max)
            line1 = $(string(var)) * " should be between $($min) and $($max).\n"
            line2_1 = "  Evaluated: " * $(string(var)) * " = "
            line2_2 = "$($(esc(var))) ∉ [$($min),$($max)]"
            throw(ArgumentError(line1 * line2_1 * line2_2))
        end
    )
end

"Check that `var` takes one value of the vector `values`."
macro check_in(var, values)
    :(
        if $(esc(var)) ∉ $values
            line1 = $(string(var)) * " should be in $($values) \n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ $($values)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

macro check_in_one_or_richness(var, S)
    :(
        if $(esc(var)) ∉ [1, $(esc(S))]
            line1 = $(string(var)) * " should be in [1, richness].\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ [1, richness].\n"
            line3 = "  Here the species richness is $($(esc(S)))."
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end

"Check that `mat` has a size `size`."
macro check_size(mat, size)
    :(
        if size($(esc(mat))) != $size
            line1 = $(string(mat)) * " should be of size $($size) \n"
            line2_1 = "  Evaluated: size(" * $(string(mat)) * ") = "
            line2_2 = "$(size($(esc(mat)))) != $($size)"
            throw(ArgumentError(line1 * line2_1 * line2_2))
        end
    )
end
#### end ####
