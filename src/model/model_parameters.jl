#=
Model parameters
=#

#### Type definition ####
mutable struct ModelParameters
    network::EcologicalNetwork
    biorates::BioRates
    environment::Environment
    functional_response::FunctionalResponse
    producer_competition::ProducerCompetition
    stochasticity::AddStochasticity
    stressor::Stressor
end
#### end ####

#### Type display ####
"""
One line ModelParameters display.
"""
function Base.show(io::IO, params::ModelParameters)
    response_type = typeof(params.functional_response)
    print(io, "ModelParameters{$response_type}")
    !get(io, :compact, false) && print(io, "(", params.network, ")")
end

"""
Multiline ModelParameters display.
"""
function Base.show(io::IO, ::MIME"text/plain", params::ModelParameters)

    # Display output
    response_type = typeof(params.functional_response)
    println(io, "ModelParameters{$response_type}:")
    println(io, "  network: ", params.network)
    println(io, "  environment: ", params.environment)
    println(io, "  biorates: ", params.biorates)
    println(io, "  functional_response: ", params.functional_response)
    println(io, "  producer_competition: ", params.producer_competition)
    println(io, "  stochasticity: ", params.stochasticity)
    println(io, "  stressor: ", params.stressor)
end
#### end ####

"""
    ModelParameters(
        network::EcologicalNetwork;
        biorates::BioRates=BioRates(foodweb),
        environment::Environment=Environment(foodweb),
        functional_response::FunctionalResponse=BioenergeticResponse(foodweb),
        producer_competition::ProducerCompetition=ProducerCompetition(foodweb),
        stochasticity::AddStochasticity=AddStochasticity(foodweb),
        stressor::Stressor=Stressor()
    )

Generate the parameters of the species community.

Default values are taken from
[Brose et al., 2006](https://doi.org/10.1890/0012-9658(2006)87%5B2411:CBRINF%5D2.0.CO%3B2).
The parameters are compartimented in different groups:

  - [`FoodWeb`](@ref): foodweb information (e.g. adjacency matrix)
  - [`BioRates`](@ref): biological species rates (e.g. growth rates)
  - [`Environment`](@ref): environmental variables (e.g. carrying capacities)
  - [`FunctionalResponse`](@ref) (F): functional response form
    (e.g. classic or bioenergetic functional response)
  - [`ProducerCompetition`](@ref): producer competition (e.g. intra and inter competition)

# Examples

```jldoctest
julia> foodweb = FoodWeb([0 1; 0 0]); # create a simple foodweb

julia> p = ModelParameters(foodweb)
ModelParameters{BioenergeticResponse}:
  network: FoodWeb(S=2, L=1)
  environment: Environment(K=[nothing, 1], T=293.15K)
  biorates: BioRates(d, r, x, y, e)
  functional_response: BioenergeticResponse
  producer_competition: ProducerCompetition((2, 2) matrix)
  stochasticity: Stochasticity not added
  stressor: Stressor(addstressor, slope, start)

julia> p.network # check that stored foodweb is the same than the one we provided
FoodWeb of 2 species:
  A: sparse matrix with 1 links
  M: [1.0, 1.0]
  metabolic_class: 1 producers, 1 invertebrates, 0 vertebrates
  method: unspecified
  species: [s1, s2]

julia> p.functional_response # default is bionergetic
BioenergeticResponse:
  B0: [0.5, 0.5]
  c: [0.0, 0.0]
  h: 2.0
  ω: (2, 2) sparse matrix

julia> classic_response = ClassicResponse(foodweb); # choose classic functional response

julia> p = ModelParameters(foodweb; functional_response = classic_response);

julia> p.functional_response # check that the functional response is now "classic"
ClassicResponse:
  c: [0.0, 0.0]
  h: 2.0
  ω: (2, 2) sparse matrix
  hₜ: (2, 2) sparse matrix
  aᵣ: (2, 2) sparse matrix
```
"""
function ModelParameters(
    network::EcologicalNetwork;
    biorates::BioRates = BioRates(network),
    environment::Environment = Environment(network),
    functional_response::FunctionalResponse = BioenergeticResponse(network),
    producer_competition::ProducerCompetition = ProducerCompetition(network),
    stochasticity::AddStochasticity = AddStochasticity(network),
    stressor::Stressor = Stressor(network)
)
    if isa(network, MultiplexNetwork) & !(isa(functional_response, ClassicResponse))
        type_response = typeof(functional_response)
        @warn "Non-trophic interactions aren't implented for '$type_response'.
            Use a functional response of type 'ClassicResponse' instead."
    end
    ModelParameters(
        network,
        biorates,
        environment,
        functional_response,
        producer_competition,
        stochasticity,
        stressor
    )
end
