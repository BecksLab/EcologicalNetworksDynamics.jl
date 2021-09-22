#=
Community
=#

function Base.show(io::IO, DFW::FoodWeb)
    N = UnipartiteNetwork(DFW.A, DFW.species)
    mthd = DFW.method
    print(io, "$(richness(N; dims=1)) species - $(links(N)) links. \n Method: $mthd")
end

function Base.show(io::IO, f::FunctionalResponse)
    
    str1 = "functional response: $(String(Symbol(f.functional_response)))"
    if f.hill_exponent == 1.0
        str2 = "type II"
    elseif f.hill_exponent == 2.0 
        str2 = "type III"
    else
        str2 = "$(f.hill_exponent)"
    end
    print(io, str1 * "\n" * str2)

end
