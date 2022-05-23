#### List potential interactions ####
"Find potential facilitation links."
function potential_facilitation_links(foodweb)
    S = richness(foodweb)
    producers = (1:S)[whoisproducer(foodweb)]
    [(i, j) for i in (1:S), j in producers if i != j] # i facilitated, j facilitating
end
#### end ####

#### Sample potential interactions ####
"Draw randomly `L` links from the list of `potential_links`."
function draw_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    L >= 0 || throw(ArgumentError("L too small: should be positive."))
    L <= Lmax || throw(ArgumentError("L too large: should be lower than $Lmax,
    the maximum number of potential interactions."))
    sample(potential_links, L, replace=false)
end

"Draw randomly from the list of `potential_links` s.t. the link connectance is `C`."
function draw_links(potential_links, C::AbstractFloat)
    0 <= C <= 1 || throw(ArgumentError("Connectance out of bounds: should be in [0,1]."))
    Lmax = length(potential_links)
    C >= 0.5 / Lmax || @warn "Low connectance: 0 link drawn."
    L = round(Int64, C * Lmax)
    draw_links(potential_links, L)
end
#### end ####

#### Generate the realized links ####
"Generate the non-trophic matrix given the interaction number or connectance."
function nontrophic_matrix(foodweb, potential_links_function, n)

    # Initialization.
    S = richness(foodweb)
    A = spzeros(S, S)
    potential_links = potential_links_function(foodweb)
    link_tuples = draw_links(potential_links, n)

    # Fill matrix with corresponding links.
    for (i, j) in realized_links
        A[i, j] = 1
    end

    A
end
#### end ####
