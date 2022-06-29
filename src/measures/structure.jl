#=
Quantifying food webs structural properties
=#

import Base.convert

"""
    convert(UnipartiteNetwork, FW::FoodWeb)

Convert a FoodWeb to its UnipartiteNetwork equivalent
"""
function convert(::Type{UnipartiteNetwork}, FW::T) where {T<:FoodWeb}
    return UnipartiteNetwork(FW.A, FW.species)
end

"Number of species in the network."
function richness(A::AbstractSparseMatrix)
    size(A, 1)
end
function richness(foodweb::FoodWeb)
    richness(foodweb.A)
end
function richness(multiplex_net::MultiplexNetwork)
    richness(multiplex_net.trophic_layer.A)
end

function _ftl(A::AbstractMatrix)
    if isa(A, AbstractMatrix{Int64})
        A = Bool.(A)
    end
    N = UnipartiteNetwork(A)
    dtp = EcologicalNetworks.fractional_trophic_level(N) #shortest path to producer
    for s in dtp

    end
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

function massratio(obj::Union{ModelParameters,FoodWeb})

    if isa(obj, ModelParameters)
        M = obj.foodweb.M
        A = obj.foodweb.A
    else
        M = obj.M
        A = obj.A
    end

    Z = mean((M./M')[findall(A)])

    return Z

end
