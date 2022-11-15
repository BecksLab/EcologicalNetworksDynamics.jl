#### Type definition ####
struct ProducerCompetition
    α::Matrix{Float64}
end
#### end ####

#### Type display ####
"One line Environment display."
function Base.show(io::IO, alpha::ProducerCompetition)
    print(io, "ProducerCompetition($(size(alpha.α)) matrix)")
end

"Multiline Environment display."
function Base.show(io::IO, ::MIME"text/plain", alpha::ProducerCompetition)

    # Display output
    println(io, "Producer competition:")
    println(io, "  α: $(size(alpha.α)) matrix")

end
#### end ####

"""
    ProducerCompetition(foodweb, α = nothing, αii = 1.0, αij = 0.0)

Create producer competition matrix for the system.

The parameters are:
- α the competition matrix, nothing by default.
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

julia> c = ProducerCompetition(foodweb, αii = 0.5, αij = 1.0)
Producer competition:
  α: (3, 3) matrix

julia> my_α = [.5 1.0 0; 1.0 .5 0; 0 0 0]
3×3 Matrix{Float64}:
 0.5  1.0  0.0
 1.0  0.5  0.0
 0.0  0.0  0.0

julia> myc = ProducerCompetition(foodweb, α = my_α)
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

        ProducerCompetition(α)
    else
        # α should be a square matrix
        @assert size(α, 1) == size(α, 2) == S
        # α should be 0 for non producers
        @assert all(α[non_producer, :] .== 0)
        @assert all(α[:, non_producer] .== 0)
    end

    ProducerCompetition(α)
end
