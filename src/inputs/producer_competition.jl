#### Type definition ####
struct ProducerCompetition
    α::SparseMatrixCSC{Float64,Int64}
end
#### end ####

#### Type display ####
"""
One line Environment display.
"""
function Base.show(io::IO, alpha::ProducerCompetition)
    print(io, "ProducerCompetition($(size(alpha.α)) matrix)")
end

"""
Multiline Environment display.
"""
function Base.show(io::IO, ::MIME"text/plain", alpha::ProducerCompetition)

    # Display output
    println(io, "Producer competition:")
    println(io, "  α: $(size(alpha.α)) matrix")

end
#### end ####

"""
    ProducerCompetition(network, α = nothing, αii = 1.0, αij = 0.0)

Create producer competition matrix of the system.

The parameters are:

  - α the competition matrix of dimensions S*S, S being the species number of the
    network. Set to nothing by default.
  - αii the intracompetition term for all species, 1.0 by default.
  - αij the interspecific competition term for all species, 0.0 by default.

By default, the producers compete only with themselves (i.e. αii = 1.0, αij = 0.0).
In the resulting α matrix, the element α[i,j] represents the percapita
effect of the species j on the species i. If α matrix is specified, it overrides
the αii and αij parameters. Moreover, all the αij coefficients should be 0 for
non producers.

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

julia> c = ProducerCompetition(foodweb; αii = 0.5, αij = 1.0)
Producer competition:
  α: (3, 3) matrix

julia> my_α = [0.5 1.0 0; 1.0 0.5 0; 0 0 0]
3×3 Matrix{Float64}:
 0.5  1.0  0.0
 1.0  0.5  0.0
 0.0  0.0  0.0

julia> myc = ProducerCompetition(foodweb; α = my_α)
Producer competition:
  α: (3, 3) matrix

julia> c.α == myc.α
true
```

See also [`ModelParameters`](@ref).
"""
function ProducerCompetition(network::EcologicalNetwork; α = nothing, αii = 1.0, αij = 0.0)
    # Matrix initialization
    S = richness(network)
    non_producer = filter(!isproducer, network)

    if isnothing(α)
        # Put the diagonal elements to αii
        α = fill(αij, S, S)
        for i in 1:S
            α[i, i] = αii
        end

        # Put coefficients of non-producers to 0
        α[non_producer, :] .= 0
        α[:, non_producer] .= 0

    else
        # α should be a square matrix
        @assert size(α, 1) == size(α, 2) == S
        # α should be 0 for non producers
        @assert all(α[non_producer, :] .== 0)
        @assert all(α[:, non_producer] .== 0)
    end

    ProducerCompetition(SparseMatrixCSC(α))
end
