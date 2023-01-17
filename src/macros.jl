#### Macros ####
# Check that `var` is lower or equal than `max`.
macro check_lower_than(var, max)
    :(
        if $(esc(var)) > $(esc(max))
            line1 =
                $(string(var)) * " should be lower than or equal to " * $(string(max)) * ".\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) > $($(esc(max)))"
            throw(ArgumentError(line1 * line2))
        end
    )
end

# Check that `var` is greater or equal than `min`.
macro check_greater_than(var, min)
    :(
        if $(esc(var)) < $(esc(min))
            line1 =
                $(string(var)) * " should be greater than or equal to " * $(string(min)) * ".\n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) < $($(esc(min)))"
            throw(ArgumentError(line1 * line2))
        end
    )
end

# Check that `var` is between `min` and `max` (bounds included).
macro check_is_between(var, min, max)
    :(
        if !($(esc(min)) <= $(esc(var)) <= $(esc(max)))
            line1 = $(string(var)) * " out of bounds.\n"
            line2 = "  Evaluated: $($(string(var))) = $($(esc(var)))\n"
            line3 = "  Expected: $($(string(var))) ∈ [$($(esc(min))), $($(esc(max)))]"
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end

macro check_is_even(x)
    :(
        if ($(esc(x)) % 2 != 0)
            line1 = $(string(x)) * " should be even.\n"
            line2 = "  Evaluated: $($(string(x))) = $($(esc(x)))\n"
            line3 = "  Expected: $($(string(x))) % 2 = 0"
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end

# Check that `var` takes one value of the vector `values`.
macro check_in(var, values)
    :(
        if $(esc(var)) ∉ $values
            line1 = $(string(var)) * " should be in $($values) \n"
            line2 = "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ $($values)"
            throw(ArgumentError(line1 * line2))
        end
    )
end

macro check_is_one_or_richness(var, S)
    :(
        if $(esc(var)) ∉ [1, $(esc(S))]
            line1 = $(string(var)) * " should be 1 or richness=$($(esc(S))).\n"
            line2 =
                "  Evaluated: " * $(string(var)) * " = $($(esc(var))) ∉ {1, $($(esc(S)))}."
            throw(ArgumentError(line1 * line2))
        end
    )
end

macro check_equal_richness(var, S)
    :(
        if $(esc(var)) != $(esc(S))
            line1 = $(string(var)) * " should be equal to richness.\n"
            line2 = "  Evaluated: $($(string(var))) = $($(esc(var)))\n"
            line3 = "  Expected: $($(string(var))) = $($(esc(S)))"
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end

macro check_size_is_richness²(mat, S)
    :(
        if size($(esc(mat))) != ($(esc(S)), $(esc(S)))
            line1 = $(string(mat)) * " should be of size (richness, richness).\n"
            line2 = "  Evaluated: size(" * $(string(mat)) * ") = $(size($(esc(mat))))\n"
            line3 = "  Expected: size(" * $(string(mat)) * ") = $(($(esc(S)),$(esc(S))))"
            throw(ArgumentError(line1 * line2 * line3))
        end
    )
end

# Check that `mat` has a size `size`.
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
