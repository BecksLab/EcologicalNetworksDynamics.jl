#### List potential interactions ####
"Find potential facilitation links."
function potential_facilitation_links(foodweb)
    S = richness(foodweb)
    producers = (1:S)[whoisproducer(foodweb)]
    [(i, j) for i in (1:S), j in producers if i != j] # i facilitated, j facilitating
end
#### end ####
