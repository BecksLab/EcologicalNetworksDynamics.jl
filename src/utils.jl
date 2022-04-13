# Small functions useful for the whole package

#### Identifying metabolic classes ####
"Helper function called by `whois...` functions (e.g. `whoisproducer`)."
function whois(metabolic_class::String, foodweb::FoodWeb)
    vec(foodweb.metabolic_class .== metabolic_class)
end
"Which species is a producer or not? Return a BitVector."
function whoisproducer(foodweb::FoodWeb)
    whois("producer", foodweb)
end
"Which species is an vertebrate or not? Return a BitVector."
function whoisvertebrate(foodweb::FoodWeb)
    whois("ectotherm vertebrate", foodweb)
end
"Which species is an invertebrate or not? Return a BitVector."
function whoisinvertebrate(foodweb::FoodWeb)
    whois("invertebrate", foodweb)
end

function whoisproducer(A)
    vec(.!any(A, dims=2))
end
#### end ####

function resourcenumber(consumer, foodweb::FoodWeb)
    sum(foodweb.A[consumer, :])
end

function resourcenumber(consumer::Vector, foodweb::FoodWeb)
    Dict(i => resourcenumber(i, foodweb) for i in unique(consumer))
end
