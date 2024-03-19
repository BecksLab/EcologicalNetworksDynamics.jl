#### Multiplex network objects ####

using ..EcologicalNetworksDynamics.MultiplexApi
import .MultiplexApi.AliasingDicts

"""
    Layer(A::SparseMatrixCSC{Bool,Int64}, intensity::Union{Nothing,Float64})

A `Layer` of an interaction type contains
two pieces of information concerning this interaction:

  - `A`: where the interactions occur given by the adjacency matrix
  - `intensity`: the intensity of the interaction
  - `f`: the functional form of the non-trophic effect on the parameter associated with the layer

The intensity is only defined for non-trophic interactions and is set to `nothing` for
trophic interactions.
"""
mutable struct Layer
    A::AdjacencyMatrix
    intensity::Union{Nothing,Float64}
    f::Union{Nothing,Function}
end

mutable struct MultiplexNetwork <: EcologicalNetwork
    layers::InteractionDict{Layer}
    M::Vector{Float64}
    species::Vector{String}
    metabolic_class::Vector{String}
end

# Define default values for all parameters.
zero_layer_A(fw::FoodWeb) = spzeros(richness(fw), richness(fw))

multiplex_defaults = MultiplexParametersDict(;
    A = InteractionDict(;
        competition = zero_layer_A,
        facilitation = zero_layer_A,
        interference = zero_layer_A,
        refuge = zero_layer_A,
        trophic = fw -> fw.A,
    ),
    intensity = InteractionDict(;
        competition = 1.0,
        facilitation = 1.0,
        interference = 1.0,
        refuge = 1.0,
        trophic = nothing,
    ),
    functional_form = InteractionDict(;
        competition = (x, δx) -> x < 0 ? x : max(0, x * (1 - δx)),
        facilitation = (x, δx) -> x * (1 + δx),
        interference = nothing,
        refuge = (x, δx) -> x / (1 + δx),
        trophic = nothing,
    ),
    symmetry = InteractionDict(;
        competition = true,
        facilitation = false,
        interference = true,
        refuge = false,
        trophic = nothing,
    ),
)

i_standards() = AliasingDicts.standards(InteractionDict)
p_standards() = AliasingDicts.standards(MultiplexParametersDict)

"""
    MultiplexNetwork(foodweb::FoodWeb; args...)

Build the `MultiplexNetwork` from a [`FoodWeb`](@ref).
A multiplex is composed of a `trophic_layer`
and several non-trophic [`Layer`](@ref) indexed by interaction types:
(`:competition`,
`:facilitation`,
`:interference` and
`:refuge`).
The `:trophic` layer is given by the [`FoodWeb`](@ref),
and other, non-trophic layers are empty by default.

There are various ways to specify non-trophic layers to be not-empty,
using variably-named `args` whose general form is either:

    <parameter_name>_<interaction_name> = value
    eg.                intensity_refuge = 4.0
    or equivalently:                I_r = 4.0

to set up `parameter` for layer `interaction`, or:

       <parameter_name> = (<interaction1>=value1, <interaction2>=value2, ...)
    eg.       intensity = (facilitation = 2.0, interference = 1.5)
    or equivalently:  I = (f = 2.0, i = 1.5)

to set up `parameter` for all layers `interaction1`, `interaction2`, etc., or again:

    <interaction_name> = (<parameter1>=value1, <parameter2>=value2, ...)
    eg.    competition = (connectance = 4, symmetry = false)
    or equivalently: c = (L = 4, s = false)

to set up `parameter1` and `parameter2` for the layer `interaction.

Valid interactions and parameters names
can be retrieved with the following two cheat-sheets:

```jldoctest
julia> interaction_names()
OrderedCollections.OrderedDict{Symbol, Vector{Symbol}} with 5 entries:
  :trophic      => [:t, :trh]
  :competition  => [:c, :cpt]
  :facilitation => [:f, :fac]
  :interference => [:i, :itf]
  :refuge       => [:r, :ref]

julia> multiplex_network_parameters_names()
OrderedCollections.OrderedDict{Symbol, Vector{Symbol}} with 6 entries:
  :adjacency_matrix => [:A, :matrix, :adj_matrix]
  :intensity        => [:I, :int]
  :functional_form  => [:F, :fn]
  :connectance      => [:C, :conn]
  :number_of_links  => [:L, :n_links]
  :symmetry         => [:s, :sym, :symmetric]
```

# Fill non-trophic layers

Specify a number of desired links to generate a non-trophic layer.

```jldoctest 1
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # 2 producers and 1 consumer

julia> MultiplexNetwork(foodweb; L_facilitation = 2) #  or 'n_links_f', or 'L_fac', etc.
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 2 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

Alternately, specify desired connectance for the layer
(a value of `1.0` creates as many links as possible).

```jldoctest 1
julia> MultiplexNetwork(foodweb; C_cpt = 1.0) #  or 'C_competition', or 'connectance_c', etc.
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 2 links
  facilitation_layer: 0 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

Alternately, provide an explicit adjacency matrix.

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]); # 2 consumers feeding on producer 1

julia> MultiplexNetwork(foodweb; A_interference = [0 0 0; 0 0 1; 0 1 0]) #  or 'matrix_i' etc.
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 0 links
  interference_layer: 2 links
  refuge_layer: 0 links
```

# Set non-trophic intensity

Non-trophic layers intensities default to '1.0'.
Modify them with corresponding arguments:

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]); # 2 producers and 1 consumer

julia> multiplex_network = MultiplexNetwork(foodweb; facilitation = (L = 1, I = 2.0));

julia> multiplex_network.layers[:facilitation] #  or [:f] or [:fac] etc.
Layer(A=AdjacencyMatrix(L=1), intensity=2.0)
```

# Change assumptions about the symmetry of non-trophic interactions

An interaction is symmetric iff
"``i`` interacts with ``j``" implies that "``j`` interacts with ``i``".
In other words, an interaction is symmetric
iff the adjacency matrix of that interaction is symmetric.

With default settings:

  - competition is symmetric
  - facilitation is not symmetric
  - interference is symmetric
  - refuge is not symmetric

Change the defaults with the appropriate arguments.

For example, competition is assumed to be symmetric,
then the number of competition links has to be even.
But you can change this default as follows:

```jldoctest a
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 1 0]);

julia> MultiplexNetwork(foodweb; competition = (sym = false, L = 1))
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 1 links
  facilitation_layer: 0 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

!!! note

    If you don't specify `sym=false` an error will be thrown.

# Construct arguments dynamically.

Sometimes you need to dynamically choose the layer or parameters in a group.
Use `Dict`s instead of named tuples to this end:

```jldoctest a
julia> MultiplexNetwork(foodweb; f = (L = 1, I = 2.0))
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 1 links
  interference_layer: 0 links
  refuge_layer: 0 links

julia> dict = Dict(:L => 1, :I => 2.0);
       b = MultiplexNetwork(foodweb; f = dict)
MultiplexNetwork of 3 species:
  trophic_layer: 2 links
  competition_layer: 0 links
  facilitation_layer: 1 links
  interference_layer: 0 links
  refuge_layer: 0 links
```

See also [`FoodWeb`](@ref), [`Layer`](@ref).
"""
function MultiplexNetwork(
    foodweb::FoodWeb;
    # The parameters to parse into actual layers.
    kwargs...,
)
    S = richness(foodweb)

    all_parms = parse_multiplex_arguments(kwargs)
    is_specified(int, parm) = haskey(all_parms[int], parm)

    # Construct the matrix from arguments.
    for int in i_standards()

        # Skip foodweb whose links have already been constructed.
        if int == :trophic
            continue
        end

        if !is_specified(int, :A)

            # The matrix needs to be constructed.
            sym = (
                is_specified(int, :symmetry) ? all_parms[int][:sym][2] :
                multiplex_defaults[:sym][int]
            )

            # Pick the right functions.
            potential_links = eval(Symbol("potential_$(int)_links"))

            if is_specified(int, :connectance)
                A = nontrophic_adjacency_matrix(
                    foodweb,
                    potential_links,
                    all_parms[int][:conn][2]::AbstractFloat;
                    symmetric = sym,
                )

            elseif is_specified(int, :n_links)
                A = nontrophic_adjacency_matrix(
                    foodweb,
                    potential_links,
                    all_parms[int][:L][2]::Integer;
                    symmetric = sym,
                )

            else
                # Nothing has actually been specified for this matrix,
                # it'll fall back on default matrix within the next loop.
                continue
            end

            # Now specified although there was no user input.
            all_parms[int][:A] = (nothing, A)
        else

            # Otherwise it's already here.
            (_, A) = all_parms[int][:A]
            @check_size_is_richness² A S

        end
    end

    # Anything not provided by user is set to default.
    # During this step, drop arguments name informations (eg. (arg, V) -> V).
    for int in i_standards(), parm in p_standards()

        if AliasingDicts.isin(parm, [:C, :L, :symmetry], MultiplexParametersDict)
            # These annex parameters don't need defaults.
            continue
        end
        if !is_specified(int, parm)
            # Missing: read from defaults.
            def = multiplex_defaults[parm][int]
            if AliasingDicts.is(parm, :A, MultiplexParametersDict)
                # Special case: this default is a function of the foodweb.
                def = def(foodweb)
            end
            # Skip 'nothing' defaults
            # to not have this ill-designed `Union{Nothing,P}` layer types
            # crawl up to the modern API.
            if isnothing(def)
                continue
            end
            all_parms[int][parm] = (nothing, def)
        end
    end

    # Restore the `nothing` values into the Internals here.
    get(i, p) = haskey(all_parms[i], p) ? all_parms[i][p][2] : nothing

    # Build layers.
    layers = InteractionDict(
        (int => Layer(get.(int, [:A, :intensity, :F])...) for int in i_standards())...,
    )

    # Create the resulting multiplex network
    MultiplexNetwork(layers, foodweb.M, foodweb.species, foodweb.metabolic_class)
end

#### Display MultiplexNetwork & NonTrophicIntensity ####
"""
One line [`Layer`](@ref) display.
"""
function Base.show(io::IO, layer::Layer)
    L = count(layer.A)
    intensity = layer.intensity
    print(io, "Layer(A=AdjacencyMatrix(L=$L), intensity=$intensity)")
end

"""
One line [`MultiplexNetwork`](@ref) display.
"""
function Base.show(io::IO, multiplex_net::MultiplexNetwork)
    S = richness(multiplex_net)
    layers = ""
    for int in i_standards()
        short = AliasingDicts.shortest(int, InteractionDict)
        layers *= ", L$(short)=$(count(multiplex_net.layers[int].A))"
    end
    print(io, "MultiplexNetwork(S=$S$layers)")
end

"""
Multiline [`MultiplexNetwork`](@ref) display.
"""
function Base.show(io::IO, ::MIME"text/plain", multiplex_net::MultiplexNetwork)

    # Specify parameters
    S = richness(multiplex_net)
    print(io, "MultiplexNetwork of $S species:")
    for int in i_standards()
        L = count(multiplex_net.layers[int].A)
        print(io, "\n  $(int)_layer: $L links")
    end
end
#### end ####

#### List potential interactions ####
"""
    potential_facilitation_links(foodweb::FoodWeb)

Find possible facilitation links.
Facilitation links can only occur from any species to a plant.
"""
function potential_facilitation_links(foodweb::FoodWeb)
    S = richness(foodweb)
    [(i, j) for i in (1:S), j in producers(foodweb) if i != j] # i --facilitates-> j
end

"""
    potential_competition_links(foodweb::FoodWeb)

Find possible competition links.
Competition links can only occur between two sessile species (producers).
"""
function potential_competition_links(foodweb::FoodWeb)
    prod = producers(foodweb)
    [(i, j) for i in prod, j in prod if i != j] # i <-competes-> j
end

"""
    potential_refuge_links(foodweb::FoodWeb)

Find possible refuge links.
Refuge links can only occur from a sessile species (producer) to a prey.
"""
function potential_refuge_links(foodweb::FoodWeb)
    [(i, j) for i in producers(foodweb), j in preys(foodweb) if i != j]
end

"""
    potential_interference_links(foodweb::FoodWeb)

Find possible interference links.
Interference links can only occur between two predators sharing at least one prey.
"""
function potential_interference_links(foodweb::FoodWeb)
    preds = predators(foodweb)
    [(i, j) for i in preds, j in preds if i != j && share_prey(i, j, foodweb)]
end

"""
Adjacency matrix of potential links given by the `potential_links` function in `net`.
"""
function A_nti_full(net::EcologicalNetwork, potential_links::Function)
    foodweb = convert(FoodWeb, net)
    S = richness(foodweb)
    potential_links = potential_links(foodweb)
    A = spzeros((S, S))
    for (i, j) in potential_links
        A[i, j] = 1
    end
    A
end

"""
    A_competition_full(net)

Adjacency matrix of all possible competition links in the network `net`.

# Example

```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]; quiet = true); # 2 producers

julia> A_competition_full(foodweb)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅   1.0
 1.0   ⋅
```

See also [`A_interference_full`](@ref),
[`A_facilitation_full`](@ref),
[`A_refuge_full`](@ref).
"""
A_competition_full(net) = A_nti_full(net, potential_competition_links)

"""
    A_facilitation_full(net)

Adjacency matrix of all possible facilitation links in the network `net`.

# Example

```jldoctest
julia> foodweb = FoodWeb([0 0; 0 0]; quiet = true); # 2 producers

julia> A_facilitation_full(foodweb)
2×2 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅   1.0
 1.0   ⋅
```

See also [`A_competition_full`](@ref),
[`A_interference_full`](@ref),
[`A_refuge_full`](@ref).
"""
A_facilitation_full(net) = A_nti_full(net, potential_facilitation_links)

"""
    A_interference_full(net)

Adjacency matrix of all possible interference links in the network `net`.

# Example

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]); # 2 consumers eating producer 1

julia> A_interference_full(foodweb)
3×3 SparseArrays.SparseMatrixCSC{Float64, Int64} with 2 stored entries:
  ⋅    ⋅    ⋅
  ⋅    ⋅   1.0
  ⋅   1.0   ⋅
```

See also [`A_competition_full`](@ref),
[`A_facilitation_full`](@ref),
[`A_refuge_full`](@ref).
"""
A_interference_full(net) = A_nti_full(net, potential_interference_links)

"""
    A_refuge_full(net)

Adjacency matrix of all possible refuge links in the network `net`.

# Example

```jldoctest
julia> foodweb = FoodWeb([0 0 0; 0 0 0; 1 0 0]; quiet = true); # consumer 3 eats producer 1

julia> A_refuge_full(foodweb)
3×3 SparseArrays.SparseMatrixCSC{Float64, Int64} with 1 stored entry:
  ⋅    ⋅    ⋅
 1.0   ⋅    ⋅
  ⋅    ⋅    ⋅
```

See also [`A_competition_full`](@ref),
[`A_interference_full`](@ref),
[`A_facilitation_full`](@ref).
"""
A_refuge_full(net) = A_nti_full(net, potential_refuge_links)
#### end ####

#### Sample potential interactions ####
"""
    draw_asymmetric_links(potential_links, L::Integer)

Draw randomly `L` links from the list of `potential_links`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    @check_is_between L 0 Lmax
    sample(potential_links, L; replace = false)
end

"""
    draw_asymmetric_links(potential_links, C::AbstractFloat)

Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn asymmetrically,
i.e. ``i`` interacts with ``j`` ⇏ ``j`` interacts with ``i``.
"""
function draw_asymmetric_links(potential_links, C::AbstractFloat)
    @check_is_between C 0 1
    Lmax = length(potential_links)
    L = round(Int64, C * Lmax)
    draw_asymmetric_links(potential_links, L)
end

"""
    draw_symmetric_links(potential_links, L::Integer)

Draw randomly `L` links from the list of `potential_links`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, L::Integer)
    Lmax = length(potential_links)
    @check_is_between L 0 Lmax
    @check_is_even L
    @check_is_even Lmax
    potential_links = asymmetrize(potential_links)
    potential_links = sample(potential_links, L ÷ 2; replace = false)
    symmetrize(potential_links)
end

"""
    draw_symmetric_links(potential_links, C::AbstractFloat)

Draw randomly from the list of `potential_links` such that the link connectance is `C`.
Links are drawn symmetrically,
i.e. ``i`` interacts with ``j`` ⇒ ``j`` interacts with ``i``.
"""
function draw_symmetric_links(potential_links, C::AbstractFloat)
    @check_is_between C 0 1
    Lmax = length(potential_links)
    L = C * Lmax
    L = 2 * round(Int64, L / 2) # round to an even number
    draw_symmetric_links(potential_links, L)
end

"""
    asymmetrize(V)

Remove duplicate tuples from a symmetric vector of tuples.
A vector `V` of tuples is said to be symmetric ⟺ ((i,j) ∈ `V` ⟺ (j,i) ∈ `V`).
The tuple that has its 1st element less than its 2nd element is kept
i.e. if i < j (i,j) is kept, and (j,i) otherwise.

See also [`symmetrize`](@ref).
"""
asymmetrize(V) = [(i, j) for (i, j) in V if i < j]

"""
    symmetrize(V)

Add symmetric tuples from an asymmetric vector of tuples.
A vector `V` of tuples is said to be asymmetric ⟺ ((i,j) ∈ `V` ⇒ (j,i) ∉ `V`).

See also [`asymmetrize`](@ref).
"""
symmetrize(V) = vcat(V, [(j, i) for (i, j) in V])
#### end ####

#### Generate the realized links ####
"""
    nontrophic_adjacency_matrix(
        foodweb::FoodWeb,
        find_potential_links::Function,
        n;
        symmetric=false)

Generate a non-trophic adjacency matrix
given the function finding potential links (`find_potential_links`)
and `n` which is interpreted as a number of links if `n:<Integer`
or as a connectance if `n:<AbstractFloat`.

See also [`potential_competition_links`](@ref), [`potential_facilitation_links`](@ref),
[`potential_interference_links`](@ref), [`potential_refuge_links`](@ref).
"""
function nontrophic_adjacency_matrix(
    foodweb::FoodWeb,
    find_potential_links::Function,
    n;
    symmetric = false,
)
    S = richness(foodweb)
    A = spzeros(Bool, S, S)
    potential_links = find_potential_links(foodweb)
    draw_links = symmetric ? draw_symmetric_links : draw_asymmetric_links
    realized_links = draw_links(potential_links, n)
    for (i, j) in realized_links
        A[i, j] = 1
    end
    A
end
#### end ####
