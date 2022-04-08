#=
Biological rates
=#

function _idproducers(A)
    isprod = (sum(A, dims=2) .== 0)
    return vec(isprod)
end

"""
    allometricgrowth(FW)

Calculates basal species (producers) growth rate using an allometric equation.
"""
function allometricgrowth(FW::FoodWeb; a::Union{Vector{T},T}=1, b::Union{Vector{T},T}=-0.25) where {T<:Real}
    return a .* (FW.M .^ b) .* vec(FW.metabolic_class .== "producer")
end

"""
    allometricmetabolism(FW)

Calculates species metabolic rates using an allometric equation.
"""
function allometricmetabolism(FW::FoodWeb; a::Union{Vector{T},T,Nothing}=nothing, b::Union{Vector{T},T,Nothing}=nothing, a_p::Real=0, a_ect::Real=0.88, a_inv::Real=0.314, b_p::Real=0, b_ect::Real=-0.25, b_inv::Real=-0.25) where {T<:Real}
    S = richness(FW)
    if isnothing(a) & isnothing(b)
        checkclass = all([m ∈ ["producer", "invertebrate", "ectotherm vertebrate"] for m in FW.metabolic_class])
        checkclass || throw(ArgumentError("By not providing any values, you are using the default allometric parameters, but to do that you need to have only producers, invertebrates and/or ectotherm vertebrates in your metabolic_class vector"))
        a, b = _defaulparameters_metabolism(FW, a_p=a_p, a_ect=a_ect, a_inv=a_inv, b_p=b_p, b_ect=b_ect, b_inv=b_inv)
    elseif isnothing(a) & !isnothing(b)
        a = _defaulparameters_metabolism(FW, a_p=a_p, a_ect=a_ect, a_inv=a_inv, b_p=b_p, b_ect=b_ect, b_inv=b_inv).a
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & isnothing(b)
        b = _defaulparameters_metabolism(FW, a_p=a_p, a_ect=a_ect, a_inv=a_inv, b_p=b_p, b_ect=b_ect, b_inv=b_inv).b
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & !isnothing(b)
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    end
    x = a .* (FW.M .^ b)
    return x
end

function _defaulparameters_metabolism(FW; a_p::Real=0, a_ect::Real=0.88, a_inv::Real=0.314, b_p::Real=0, b_ect::Real=-0.25, b_inv::Real=-0.25)
    a = zeros(length(FW.species))
    a[vec(FW.metabolic_class .== "producer")] .= a_p
    a[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= a_ect
    a[vec(FW.metabolic_class .== "invertebrate")] .= a_inv
    b = zeros(length(FW.species))
    b[vec(FW.metabolic_class .== "producer")] .= b_p
    b[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= b_ect
    b[vec(FW.metabolic_class .== "invertebrate")] .= b_inv
    return (a=a, b=b)
end

"""
    allometricmaxconsumption(FW)

Calculates species metabolic rates using an allometric equation.
"""
function allometricmaxconsumption(FW::FoodWeb; a::Union{Vector{T},T,Nothing}=nothing, b::Union{Vector{T},T,Nothing}=nothing, a_ect::Real=4.0, a_inv::Real=8.0, b_ect::Real=0, b_inv::Real=0) where {T<:Real}

    S = richness(FW)
    if isnothing(a) & isnothing(b)
        checkclass = all([m ∈ ["producer", "invertebrate", "ectotherm vertebrate"] for m in FW.metabolic_class])
        checkclass || throw(ArgumentError("By not providing any values, you are using the default allometric parameters, but to do that you need to have only producers, invertebrates and/or ectotherm vertebrates in your metabolic_class vector"))
        a, b = _defaulparameters_maxconsumption(FW, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv)
    elseif isnothing(a) & !isnothing(b)
        a = _defaulparameters_maxconsumption(FW, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv).a
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & isnothing(b)
        b = _defaulparameters_maxconsumption(FW, a_ect=a_ect, a_inv=a_inv, b_ect=b_ect, b_inv=b_inv).b
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & !isnothing(b)
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    end
    x = a .* (FW.M .^ b)
    isp = _idproducers(FW.A)
    x[isp] .= 0.0
    return x
end

function _defaulparameters_maxconsumption(FW; a_ect::Real=4, a_inv::Real=8, b_ect::Real=0, b_inv::Real=0)
    a = zeros(length(FW.species))
    a[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= a_ect
    a[vec(FW.metabolic_class .== "invertebrate")] .= a_inv
    b = zeros(length(FW.species))
    b[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= b_ect
    b[vec(FW.metabolic_class .== "invertebrate")] .= b_inv
    return (a=a, b=b)
end

"""
    TODO
"""
function BioRates(FW::FoodWeb
    ; rmodel::Union{Function,Nothing}=allometricgrowth, rparameters::Union{NamedTuple,Nothing}=nothing, xmodel::Union{Function,Nothing}=allometricmetabolism, xparameters::Union{NamedTuple,Nothing}=nothing, ymodel::Union{Function,Nothing}=allometricmaxconsumption, yparameters::Union{NamedTuple,Nothing}=nothing, r::Union{Vector{<:Real},Nothing}=nothing, x::Union{Vector{<:Real},Nothing}=nothing, y::Union{Vector{<:Real},Nothing}=nothing
)

    isnothing(rparameters) || _checkparamtupleR(rparameters)
    isnothing(xparameters) || _checkparamtupleX(xparameters)
    isnothing(yparameters) || _checkparamtupleY(yparameters)

    S = richness(FW)

    if !isnothing(r)
        isequal(length(r))(S) || throw(ArgumentError("r should be a vector of length richness(FW)"))
    else
        if isnothing(rparameters)
            r = rmodel(FW)
        else
            _checkparamtupleR(rparameters)
            rp = Dict(map((i, j) -> i => j, keys(rparameters), values(rparameters)))
            r = rmodel(FW; rp...)
        end
    end

    if !isnothing(x)
        isequal(length(x))(S) || throw(ArgumentError("x should be a vector of length richness(FW)"))
    else
        if isnothing(xparameters)
            x = xmodel(FW)
        else
            _checkparamtupleX(xparameters)
            xp = Dict(map((i, j) -> i => j, keys(xparameters), values(xparameters)))
            x = rmodel(FW; xp...)
        end
    end

    if !isnothing(y)
        isequal(length(y))(S) || throw(ArgumentError("y should be a vector of length richness(FW)"))
    else
        if isnothing(yparameters)
            y = ymodel(FW)
        else
            _checkparamtupleY(yparameters)
            yp = Dict(map((i, j) -> i => j, keys(yparameters), values(yparameters)))
            y = rmodel(FW; yp...)
        end
    end

    return BioRates(r, x, y)

end

function _checkparamtupleR(nt::NamedTuple)
    expectednames = ["a", "b"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the growth rate should be specified in a NamedTuple with fields a (constants) and b (exponents). More details in the docs."))
end

function _checkparamtupleX(nt::NamedTuple)
    expectednames = ["a", "b", "a_p", "b_p", "a_ect", "b_ect", "a_inv", "b_inv"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the metabolic rate should be specified in a NamedTuple with possible fields: a, b, a_p, b_p, a_inv, b_inv, a_ect, b_ect. More details in the docs."))
end

function _checkparamtupleY(nt::NamedTuple)
    expectednames = ["a", "b", "a_ect", "b_ect", "a_inv", "b_inv"]
    ntnames = collect(string.(keys(nt)))
    namesvalid = [n in expectednames for n in ntnames]
    all(namesvalid) || throw(ArgumentError("The parameters for the max. consumption rate should be specified in a NamedTuple with possible fields: a, b, a_inv, b_inv, a_ect, b_ect. More details in the docs."))
end
