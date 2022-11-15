#### Type definition ####
mutable struct ProducerCompetition
    α::Matrix{Float64}
    αii::Any
    αij::Any
end
#### end ####

#### Type display ####
"One line Environment display."
function Base.show(io::IO, alpha::ProducerCompetition)
    print(io, "ProducerCompetition(αii= $(alpha.αii), αij = $(alpha.αij))")
end

"Multiline Environment display."
function Base.show(io::IO, ::MIME"text/plain", alpha::ProducerCompetition)

    # Display output
    println(io, "Producer competition:")
    println(io, "  α: $(size(alpha.α)) matrix")
    println(io, "  αii: $(alpha.αii)")
    print(io, "  αij: $(alpha.αij)")

end
#### end ####

"""
    ProducerCompetition(foodweb, αii = 1.0, αij = 0.0)

Create producer competition matrix for the system.

The parameters are:
- αii the intracompetition term for all species, 1.0 by default.
- αij the interspecific competition term for all species.
By default, the carrying capacities of producers are assumed to be 1 while capacities of
consumers are assumed to be `nothing` as consumers do not have a growth term.

# Examples
```jldoctest
julia> A = [0 0 0; 0 0 0; 0 0 1]
3×3 Matrix{Int64}:
 0  0  0
 0  0  0
 0  0  1

julia> foodweb = FoodWeb(A)
FoodWeb of 3 species:
  A: sparse matrix with 1 links
  M: [1.0, 1.0, 1.0]
  metabolic_class: 2 producers, 1 invertebrates, 0 vertebrates
  method: unspecified
  species: [s1, s2, s3]

julia> ProducerCompetition(foodweb, αii = 0.5, αij = 1.0)
Producer competition:
  α: (3, 3) matrix
  αii: 0.5 
  αij: 1.0
```

See also [`ModelParameters`](@ref).
"""
function ProducerCompetition(network::EcologicalNetwork; αii = 1.0, αij = 0.0)
    # Matrix initialization
    S = richness(network)
    c = fill(αij, S, S)
    # Put the diagonal elements to αii
    c[CartesianIndex.(axes(c, 1), axes(c, 2))] = repeat([αii], S)

    # Put coefficients of non-producers to 0
    non_producer = filter(!isproducer, network)
    c[non_producer, :] .= 0
    c[:, non_producer] .= 0
    ProducerCompetition(c, αii, αij)
end
