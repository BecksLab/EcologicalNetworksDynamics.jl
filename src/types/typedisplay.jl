#=
Community
=#

function Base.show(io::IO, DFW::FoodWeb)
    N = UnipartiteNetwork(DFW.A, DFW.species)
    mthd = DFW.method
    print(io, "$(richness(N; dims=1)) species - $(links(N)) links. \n Method: $mthd")
end