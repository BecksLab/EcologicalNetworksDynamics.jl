#=
Metabolic losses
=#

metabolic_loss(i, B, params::ModelParameters) = params.biorates.x[i] * B[i]
# Code generation version (↑ ↑ ↑ DUPLICATED FROM ABOVE ↑ ↑ ↑).
# (update together as long as the two coexist)
function metabolism_loss(i, parms::ModelParameters)
    B_i = :(B[$i])
    x_i = parms.biorates.x[i]
    (x_i == 0) && return 0 #  Just to simplify expressions.
    :($x_i * $B_i)
end
