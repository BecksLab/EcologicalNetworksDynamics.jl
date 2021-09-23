#=
Biological rates
=#

function _idproducers(A)
    isprod = (sum(A, dims = 2) .== 0)
    return vec(isprod)
end

"""
    allometricgrowth(FW)

Calculates basal species (producers) growth rate using an allometric equation. 
"""
function allometricgrowth(FW::FoodWeb; a::Union{Vector{T}, T} = 1, b::Union{Vector{T}, T} = -0.25) where {T<:Real}
    return a .* (FW.M .^ b) .* vec(FW.metabolic_class .== "producer") 
end

"""
    allometricmetabolism(FW)

Calculates species metabolic rates using an allometric equation. 
"""
function allometricmetabolism(FW::FoodWeb; a::Union{Vector{T}, T, Nothing} = nothing, b::Union{Vector{T}, T, Nothing} = nothing, a_p::Real = 0, a_ect::Real = 0.88, a_inv::Real = 0.314, b_p::Real = 0, b_ect::Real = -0.25, b_inv::Real = -0.25) where {T<:Real}
    S = richness(FW)
    if isnothing(a) & isnothing(b)
        checkclass = all([m ∈ ["producer", "invertebrate", "ectotherm vertebrate"] for m in FW.metabolic_class])
        checkclass || throw(ArgumentError("By not providing any values, you are using the default allometric parameters, but to do that you need to have only producers, invertebrates and/or ectotherm vertebrates in your metabolic_class vector"))    
        a, b = _defaulparameters_metabolism(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv)
    elseif isnothing(a) & !isnothing(b)
        a = _defaulparameters_metabolism(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv).a
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & isnothing(b)
        b = _defaulparameters_metabolism(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv).b
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & !isnothing(b)
        (isequal(length(a))(S)) | (isequal(length(a))(1)) || throw(ArgumentError("a should be either a single value or a vector with as many values as there are species in the food web"))
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    end
    x = a .* (FW.M .^ b)
    return x
end

function _defaulparameters_metabolism(FW; a_p::Real = 0, a_ect::Real = 0.88, a_inv::Real = 0.314, b_p::Real = 0, b_ect::Real = -0.25, b_inv::Real = -0.25) 
    a = zeros(length(FW.species))
    a[vec(FW.metabolic_class .== "producer")] .= a_p
    a[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= a_ect
    a[vec(FW.metabolic_class .== "invertebrate")] .= a_inv
    b = zeros(length(FW.species))
    b[vec(FW.metabolic_class .== "producer")] .= b_p
    b[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= b_ect
    b[vec(FW.metabolic_class .== "invertebrate")] .= b_inv
    return (a = a, b = b)
end

"""
    allometricmaxconsumption(FW)

Calculates species metabolic rates using an allometric equation. 
"""
function allometricmaxconsumption(FW::FoodWeb; a::Union{Vector{T}, T, Nothing} = nothing, b::Union{Vector{T}, T, Nothing} = nothing, a_p::Real = 0, a_ect::Real = 4.0, a_inv::Real = 8.0, b_p::Real = 0, b_ect::Real = 0, b_inv::Real = 0) where {T<:Real}
    
    S = richness(FW)
    if isnothing(a) & isnothing(b)
        checkclass = all([m ∈ ["producer", "invertebrate", "ectotherm vertebrate"] for m in FW.metabolic_class])
        checkclass || throw(ArgumentError("By not providing any values, you are using the default allometric parameters, but to do that you need to have only producers, invertebrates and/or ectotherm vertebrates in your metabolic_class vector"))    
        a, b = _defaulparameters_maxconsumption(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv)
    elseif isnothing(a) & !isnothing(b)
        a = _defaulparameters_maxconsumption(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv).a
        (isequal(length(b))(S)) | (isequal(length(b))(1)) || throw(ArgumentError("b should be either a single value or a vector with as many values as there are species in the food web"))
    elseif !isnothing(a) & isnothing(b)
        b = _defaulparameters_maxconsumption(FW, a_p, a_ect, a_inv, b_p, b_ect, b_inv).b
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

function _defaulparameters_maxconsumption(FW; a_p::Real = 0, a_ect::Real = 4, a_inv::Real = 8, b_p::Real = 0, b_ect::Real = 0, b_inv::Real = 0) 
    a = zeros(length(FW.species))
    a[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= a_ect
    a[vec(FW.metabolic_class .== "invertebrate")] .= a_inv
    b = zeros(length(FW.species))
    b[vec(FW.metabolic_class .== "ectotherm vertebrate")] .= b_ect
    b[vec(FW.metabolic_class .== "invertebrate")] .= b_inv
    return (a = a, b = b)
end
