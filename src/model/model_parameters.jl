#=
Model parameters
=#

"""
    ModelParameters(
        FoodWeb::FoodWeb;
        BioRates::BioRates=BioRates(foodweb),
        Environment::Environment=Environment(foodweb),
        F::FunctionalResponse=BioenergeticResponse(foodweb)
    )

Generate the parameters of the species community.

Default values are taken from
[Brose et al., 2006](https://doi.org/10.1890/0012-9658(2006)87[2411:CBRINF]2.0.CO;2).
The parameters are compartimented in different groups:
- [`FoodWeb`](@ref): foodweb information (e.g. adjacency matrix)
- [`BioRates`](@ref): biological species rates (e.g. growth rates)
- [`Environment`](@ref): environmental variables (e.g. carrying capacities)
- [`FunctionalResponse`](@ref) (F): functional response form
    (e.g. classic or bioenergetic functional response)

# Examples
```jldoctest
julia> foodweb = FoodWeb([0 1; 0 0]); # create a simple foodweb

julia> p = ModelParameters(foodweb) # default
Model parameters are compiled:
FoodWeb - 🕸
BioRates - 📈
Environment - 🌄
FunctionalResponse - 🍖

julia> p.foodweb # check that stored foodweb is the same than the one we provided
2 species - 1 links.
 Method: unspecified

julia> p.functional_response # default is bionergetic
Bioenergetic functional response
hill exponent = 2.0

julia> classic_response = ClassicResponse(foodweb); # choose classic functional response

julia> p = ModelParameters(foodweb, functional_response = classic_response);

julia> p.functional_response # check that the functional response is now "classic"
Classic functional response
hill exponent = 2.0
```
"""
function ModelParameters(
    foodweb::FoodWeb;
    biorates::BioRates=BioRates(foodweb),
    environment::Environment=Environment(foodweb),
    functional_response::FunctionalResponse=BioenergeticResponse(foodweb)
)

    ModelParameters(foodweb, biorates, environment, functional_response)
end
