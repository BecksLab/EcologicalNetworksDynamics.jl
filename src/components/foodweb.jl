# Foodweb aka. "Trophic layer",
# is special because it does structure the whole network
# in a way that makes it a dependency
# of numerous other biorates and interaction layers.
# Typically, many default values are calculated from this layer,
# and values checks are performed against this layer.

#-------------------------------------------------------------------------------------------
# Specify from trophic edges:
#  - binary matrix
#  - adjacency lists
#  - random links drawn according to the given model

"""
DOCSTRING FOR FOODWEB
"""
mutable struct Foodweb <: ModelBlueprint
    A::@GraphData {SparseMatrix, Adjacency}{:bin}

    # Specify edges by hand.
    Foodweb(A) = new(@tographdata A EA{:bin})

    # Or draw them at random.
    # These models typically require a value for S,
    # which will be used to imply the number of species
    # if the species component is automatically added,
    # but which must *match* it if already present.
    # There is no way to avoid this possible repetition of S
    # without allowing stochastic / fallible component expansion.
    # Fortunately, most users will just imply the species compartment
    # from the foodweb itself.
    # TODO: stochastic expansion *could* actually happen during early check,
    # so that failures would be okay,
    # and the behaviour would match the behaviour of non-trophic layers.
    # This would result in other blueprints needing to be defined for the foodweb component
    # like FoodwebFromNiche and FoodwebFromCascade.
    # Wait on framework refactoring to improve semantics and ergonomics first?
    function Foodweb(model::Union{Symbol,AbstractString}; kwargs...)
        model = @tographdata model Y{}

        @kwargs_helpers kwargs

        given(:S) || argerr("Random foodweb models requires a number of species 'S'.")
        S = take!(:S)

        # Default values.
        rc = take_or!(:reject_cycles, false)
        rd = take_or!(:reject_if_disconnected, true)
        max = take_or!(:max_iterations, 10^5)

        @expand_if_symbol(
            model,

            # The niche model is either parametrized with C or L.
            :niche => begin

                (given(:C) || given(:L)) ||
                    argerr("The niche model requires either a connectance value 'C' \
                            or a number of links 'L'.")

                (given(:C) && given(:L)) &&
                    argerr("Cannot provide both a connectance 'C' \
                            and a number of links 'L'.")

                if given(:C)

                    C = take!(:C, Float64)
                    tol = take_or!(:tol_C, 0.1 * C)
                    no_unused_arguments()

                    #! format: off
                    Internals.model_foodweb_from_C(
                        Internals.nichemodel,
                        S, C, nothing, # old 'p_forbidden' ?
                        tol, rc, rd, max,
                    )
                    #! format: on
                else

                    L = take!(:L, Int64)
                    tol = take_or!(:tol_L, round(Int64, 0.1 * L))
                    no_unused_arguments()

                    #! format: off
                    Internals.model_foodweb_from_L(
                        Internals.nichemodel,
                        S, L, nothing, # old 'p_forbidden' ?
                        tol, rc, rd, max,
                    )
                    #! format: on
                end
            end,

            # The cascade model is only parametrized from C.
            :cascade => begin

                given(:C) || argerr("The cascade model requires a connectance value 'C'.")

                C = take!(:C)
                tol = take_or!(:tol_C, 0.1 * C)
                no_unused_arguments()

                #! format: off
                Internals.model_foodweb_from_C(
                    Internals.cascademodel,
                    S, C, nothing, # old 'p_forbidden' ?
                    tol, rc, rd, max,
                )
                #! format: on
            end
        )
        A = model.edges
        new(A)
    end
end

function F.early_check(_, bp::Foodweb)
    (; A) = bp
    if A isa AbstractMatrix
        n, m = size(A)
        n == m || checkfails("The adjacency matrix of size $((m, n)) is not squared.")
    end
end

# If needed, infer the number of species from adjacency data.
function Species(bp::Foodweb)
    (; A) = bp
    if A isa AbstractMatrix
        S = size(A, 1)
        Species(S)
    elseif A isa BinAdjacency{Int64}
        S = refspace(A)
        Species(S)
    elseif A isa BinAdjacency{Symbol}
        names = refs(A)
        Species(names)
    end
end

function F.check(m, bp::Foodweb)
    (; A) = bp
    (; S) = m
    index = m._foodweb._species_index
    @check_size_if_matrix A (S, S)
    @check_refs_if_list A :species index
end

function F.expand!(m, bp::Foodweb)
    (; A) = bp
    index = m._foodweb._species_index

    @to_sparse_matrix_if_adjacency A index index

    # Internal network is guaranteed to be an 'Internals.FoodWeb'
    # because NTI components cannot be set before 'Foodweb' component.
    fw = m.network
    fw.A = A
    fw.method = "from component" # (internals legacy)
end

@component Foodweb implies(Species)
export Foodweb

# Consistency alias.
const TrophicLayer = Foodweb
export TrophicLayer

# ==========================================================================================
# Foodweb queries.

# Topology.
@expose_data edges begin
    property(trophic_links, A)
    get(TrophicLinks{Bool}, sparse, "trophic link")
    ref(m -> m._foodweb.A)
    @species_index
    depends(Foodweb)
end

# Number of links.
@expose_data graph begin
    property(n_trophic_links)
    ref_cache(m -> sum(m._trophic_links))
    get(m -> m._n_trophic_links)
    depends(Foodweb)
end

# Trophic levels.
@expose_data nodes begin
    property(trophic_levels)
    get(TrophicLevels{Float64}, "species")
    ref_cache(m -> Internals.trophic_levels(m._trophic_links))
    @species_index
    depends(Foodweb)
end

# More elaborate queries.
# TODO: abstract over the following to reduce boilerplate.
# as it all just stems from sparse boolean node information.
include("./producers-consumers.jl")
include("./preys-tops.jl")

#-------------------------------------------------------------------------------------------
# Get a sparse matrix highlighting only the producer-to-producer links.

function calculate_producers_links(model)
    (; S) = model
    prods = model.producers_indices
    res = spzeros(Bool, S, S)
    for i in prods, j in prods
        res[i, j] = true
    end
    res
end

@expose_data edges begin
    property(producers_links)
    get(ProducersLinks{Bool}, sparse, "producer link")
    ref_cache(calculate_producers_links)
    @species_index
    depends(Foodweb)
end

#-------------------------------------------------------------------------------------------
# Get a sparse matrix highlighting only 'herbivorous' trophic links: consumers-to-producers.
#                                    or 'carnivorous' trophic links: consumers-to-consumers.

function calculate_herbivorous_links(model)
    (; S, _trophic_links) = model
    res = spzeros(Bool, S, S)
    preds, preys, _ = findnz(_trophic_links)
    for (pred, prey) in zip(preds, preys)
        is_producer(model, prey) && (res[pred, prey] = true)
    end
    res
end

function calculate_carnivorous_links(model)
    (; S, _trophic_links) = model
    res = spzeros(Bool, S, S)
    preds, preys, _ = findnz(_trophic_links)
    for (pred, prey) in zip(preds, preys)
        is_consumer(model, prey) && (res[pred, prey] = true)
    end
    res
end

@expose_data edges begin
    property(herbivorous_links)
    get(HerbivorousLinks{Bool}, sparse, "herbivorous link")
    ref_cache(calculate_herbivorous_links)
    @species_index
    depends(Foodweb)
end

@expose_data edges begin
    property(carnivorous_links)
    get(CarnivorousLinks{Bool}, sparse, "carnivorous link")
    ref_cache(calculate_carnivorous_links)
    @species_index
    depends(Foodweb)
end

# ==========================================================================================
# Display.

# Blueprint.
function Base.show(io::IO, fw::Foodweb)
    (; A) = fw
    L = if A isa AbstractMatrix
        sum(A)
    else
        sum(length.(values(A)))
    end
    print(io, "blueprint for Foodweb with $L trophic link$(L == 1 ? "" : "s")")
end

function Base.show(io::IO, ::MIME"text/plain", fw::Foodweb)
    (; A) = fw
    print(io, "$fw:\n  A:")
    if A isa AbstractMatrix
        println(io, " " * repr(MIME("text/plain"), A))
    else
        for (pred, preys) in A
            preys =
                isempty(preys) ? "nothing" : join((repr(p) for p in preys), ", ", " and ")
            print(io, "\n  $(repr(pred)) eats $preys")
        end
    end
end

# Component.
function F.display(model, fw::Type{Foodweb})
    n = model.n_trophic_links
    "Foodweb: $n link$(n > 1 ? "s" : "")"
end
