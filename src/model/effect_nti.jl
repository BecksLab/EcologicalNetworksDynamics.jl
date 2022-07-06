# EFFECT OF NON-TROPHIC INTERACTIONS ON MODEL PARAMETERS

"Effect of competition on the net growth rate."
function effect_competition(G_net, i, B, network::MultiplexNetwork)
    isproducer(i, network) || return G_net
    c0 = network.competition_layer.intensity
    competitors = network.competition_layer.A[:, i] # sp competing for space with sp i
    δG_net = c0 * sum(competitors .* B)
    network.competition_layer.f(G_net, δG_net)
end
effect_competition(G_net, _, _, _::FoodWeb) = G_net

"Effect of facilitation on intrinsic growth rate."
function effect_facilitation(r, i, B, network::MultiplexNetwork)
    f0 = network.facilitation_layer.intensity
    facilitating_species = network.facilitation_layer.A[:, i]
    δr = f0 * sum(B .* facilitating_species)
    network.facilitation_layer.f(r, δr)
end

"Effect of refuge on attack rate."
function effect_refuge(aᵣ, B, network::MultiplexNetwork)
    r0 = network.refuge_layer.intensity
    r0 > 0 || return aᵣ # r0 = 0 ⇒ no effect of refuge
    A_refuge = network.refuge_layer.A
    links(A_refuge) > 0 || return aᵣ # no refuge links ⇒ no effect of refuge
    f_refuge = network.refuge_layer.f
    S = richness(A_refuge)
    prey = preys(aᵣ)
    aᵣ_refuge = spzeros(Float64, S, S)
    for i in prey
        providing_refuge = A_refuge[:, i] # species providing a refuge to 'prey'
        δaᵣ = r0 * sum(providing_refuge .* B)
        for j in aᵣ[:, i].nzind
            aᵣ_refuge[j, i] = f_refuge(aᵣ[j, i], δaᵣ)
        end
    end
    aᵣ_refuge
end
