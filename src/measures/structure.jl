#=
Quantifying food webs structural properties
=#

import Base.convert

"""
    convert(UnipartiteNetwork, FW::FoodWeb) 

Convert a FoodWeb to its UnipartiteNetwork equivalent
"""
function convert(::Type{UnipartiteNetwork}, FW::T) where {T <: FoodWeb}
    return UnipartiteNetwork(FW.A, FW.species)
end

"""
    richness(FW::FoodWeb)) 

Returns the number of species in the food web
"""
function EcologicalNetworks.richness(FW::FoodWeb)
    N = convert(UnipartiteNetwork, FW)
    return richness(N)
end


function _gettrophiclevels(A::AbstractMatrix)
    if isa(A, AbstractMatrix{Int64}) 
        A = Bool.(A)
    end
    tl = trophic_level(UnipartiteNetwork(A))
    tl_val = collect(values(tl))
    tl_keys = keys(tl)
    tl_species = parse.(Int64, [split(t, "s")[2] for t in tl_keys])
    tl_sp = sortperm(tl_species)
    return tl_val[tl_sp]
end

function massratio(obj::Union{ModelParameters, FoodWeb})

    if isa(obj, ModelParameters)
        M = obj.FoodWeb.M
        A = obj.FoodWeb.A
    else
        M = obj.M
        A = obj.A
    end

    Z = mean((M ./ M')[findall(A)])

    return Z

end