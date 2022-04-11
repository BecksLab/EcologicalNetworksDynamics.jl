"""
    environment()

TODO
"""
function Environment(FW::FoodWeb; K::Union{TP,Vector{TP}}=1, T::TP=293.15) where {TP<:Real}
    if isa(K, Vector)
        isequal(length(K))richness(FW) || throw(ArgumentError("K should be either a single value or a vector of length richness(FoodWeb)"))
    else
        K = repeat([K], richness(FW))
        K[.!whoisproducer(FW.A)] .= 0
    end
    return Environment(K, T)
end
