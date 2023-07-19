#=
Metabolic losses
=#

metabolic_loss(i, B, params::ModelParameters) = params.biorates.x[i] * B[i]
# Code generation version (raw) (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
function metabolism_loss(i, parms::ModelParameters)
    B_i = :(B[$i])
    x_i = parms.biorates.x[i]
    (x_i == 0) && return 0 #  Just to simplify expressions.
    :($x_i * $B_i)
end

# Code generation version (compact):
# Explain how to efficiently construct all values of eating/being_eaten,
# and provide the additional/intermediate data needed.
# This code assumes that dB[i] has already been *initialized*.
function metabolism_loss(parms::ModelParameters, ::Symbol)

    # Pre-calculate skips over lossless species.
    data = Dict(:loss => [(i, x) for (i, x) in enumerate(parms.biorates.x) if x != 0])

    code = [:(
        for (i, x_i) in loss #  (skips over null terms)
            dB[i] -= x_i * B[i]
        end
    )]

    code, data
end

natural_death_loss(i, B, params::ModelParameters) = params.biorates.d[i] * B[i]
# Code generation version (raw) (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
function natural_death_loss(i, parms::ModelParameters)
    B_i = :(B[$i])
    d_i = parms.biorates.d[i]
    :($d_i * $B_i)
end
# Code generation version (compact) is integrated to `consumption`
# because it needs one full iteration over 1:S.
# This is about to change in upcoming refactorization of the boost option.
