#=
AlleeEffect
=#

#### Type definiton ####
mutable struct AlleeEffect
    addallee::Bool
    target::Symbol
    μ::Real
    β::Real
    exponent::Real
end
#### end ####

#### Type display ####
"""
One line [`AlleeEffect`](@ref) display.
"""
function Base.show(io::IO, allee_effect::AlleeEffect)
    if allee_effect.addallee == true
        print(io, "AlleeEffect(addallee, target, μ, β, exponent)")
    else
        print(io, "Allee effects not added")
    end
end

"""
Multiline [`AlleeEffect`](@ref) display.
"""
function Base.show(io::IO, ::MIME"text/plain", allee_effect::AlleeEffect)
    if allee_effect.addallee == true
        addallee = allee_effect.addallee
        target = allee_effect.target
        mu = allee_effect.μ
        beta = allee_effect.β
        exponent = allee_effect.exponent

        println(io, "AlleeEffect:")
        println(io, "  addallee: $addallee")
        println(io, "  target: $target")
        println(io, "  μ: $mu")
        println(io, "  β: $beta")
        println(io, "  exponent: $exponent")

    else
        println(io, "AlleeEffect:")
        print(io, "  Allee effects not added")
    end
end
#### end ####

"""
Literally all I need here is a switch and some values:
"""

function AlleeEffect(fw::EcologicalNetwork; addallee::Bool = false, target = :x, μ::Real = 0, β::Real = 0, exponent::Real = 0)

    target ∈ [:x, :e] ||
        throw(ArgumentError("Invalid 'target': should be :x or :e."))
    AlleeEffect(addallee, target, μ, β, exponent)
     
end