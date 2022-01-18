#=
Consumption
=#

function consumption(biomass, FW::FoodWeb, BR::BioRates, FR::FunctionalResponse, E::Environment)

    xyb = BR.x .* BR.y .* biomass
    Fij = FR.functional_response(biomass, FW, FR.ω, FR.B0, FR.hill_exponent, FR.c)
    feeding = xyb .* Fij
    assim = (feeding ./ FR.e) .* FW.A
    loss = vec(sum(assim, dims = 1))
    gain = vec(sum(feeding, dims = 2))

    return (gain, loss)
end