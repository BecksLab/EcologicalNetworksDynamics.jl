# How to generate multiplex networks?

```@setup befwm2
using BEFWM2
```

A multiplex network is a network that contains several types of interactions.
The interaction types are gathered by layers,
where one layer contains all the interactions of a given type.
The network backbone is the trophic layer,
on top of which are added the layers of the non-trophic interactions
(i.e. non-feeding interactions).
Moreover, all the layers share the same set of nodes that are the species of the community.
In this package, four types of non-trophic interactions are available:

- [Interference between predators](@ref)
- [Plant facilitation](@ref)
- [Competition for space](@ref)
- [Refuge provisioning](@ref)

We choose these four non-trophic interactions because
they are known, theoretically and empirically, to significantly impact
the dynamics of ecological communities
(see [Miele et al. 2019](https://doi.org/10.1371/journal.pcbi.1007269)).

In the following, after a short introduction on
how to build a minimal multiplex network from a foodweb,
we go over the types of the non-trophic interactions one by one.

!!! warning
    The non-trophic interactions are only available for the [`ClassicResponse`](@ref).
    For more details about the different functional responses
    see [How to choose the functional response?](@ref)

## Introduction to [`MultiplexNetwork`](@ref)

As explained previously, a multiplex network is a foodweb, i.e. a trophic network,
on top of which has been added non-trophic layer(s).
Thus, the first step to create your first multiplex network is to generate the foodweb
(for more details see [How to generate foodwebs?](@ref))
which is the backbone of the multiplex network.

```@repl befwm2
A = [0 0 0; 1 0 0; 0 1 0]; # 1 producer ⋅ 2 eats 1 ⋅ 3 eats 2
foodweb = FoodWeb(A) # build foodweb from adjacency matrix
```

Now that your foodweb is created, you can create a [`MultiplexNetwork`](@ref)
as follow:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb)
```

As we only give the foodweb to the [`MultiplexNetwork`](@ref) method
without additional argument,
the number of non-trophic links are set to zero.
Thus, by default the multiplex network only contains trophic interactions
which are stored in the field `trophic_layer`,
and the non-trophic layers
(`competition_layer`, `facilitation_layer`, `interference_layer` and `refuge_layer`)
are empty.

Each [`Layer`](@ref) contains two fields:

- `adjacency`: the adjacency matrix that defines where the interactions occur
- `intensity`: the intensity of the interaction (defined only for non-trophic interactions)

```@repl befwm2
multiplex_network.trophic_layer
```

Lastly, before explaining how to fill the non-trophic layers,
note that the [`MultiplexNetwork`](@ref) contains,
as the [`FoodWeb`](@ref),
the species identities, metabolic classes, and body-mass.

```@repl befwm2
multiplex_network.species_id # species identities
multiplex_network.metabolic_class # metabolic classes
multiplex_network.bodymass # individual body mass
```

## Competition for space

### Definition

Competition for space happens between sessile species (mostly producers).
As for the [Interference between predators](@ref),
the interaction is assumed to be symmetric,
i.e. if species ``i`` competes with species ``j``
then species ``j`` competes with species ``i``.
In other words, the adjacency matrix of competition links is symmetric.

The competition for space translates as decrease of net growth rates
of the competing species.
Formally, we define the net growth rate as:

```math
G_\text{net} = r_i G_i + \sum_{j \in \{\text{preys}\}} e_{ij} F_{ij} - x_i
```

Where:

- ``r_i G_i`` is the growth term for producers
- ``\sum_{j \in \{\text{preys}\}} e_{ij} F_{ij}`` is the biomass gained by species ``i``
    due to prey consumption
- ``x_i`` is the metabolic loss of species ``i``

When competition occurs and if ``G_\text{net}`` is positive, then ``G_\text{net}`` becomes:

```math
G_\text{net} \rightarrow G_\text{net} (1 - c_0 \sum_{k \in \{\text{comp}\}} (A_\text{comp})_{ik} B_k)
```

With:

- ``A_\text{comp}`` the adjacency matrix of competition links
- ``c_0`` the intensity of competition interactions
- ``B_k`` the biomass of species ``k``

!!! note
    If ``G_\text{net}`` is negative, even if a competition link is present,
    ``G_\text{net}`` is let unchanged.

### Add interactions to the [`MultiplexNetwork`](@ref)

Non-trophic layers can be filled in three ways, either by providing a:
- number of non-trophic links
- connectance of non-trophic links
- custom adjacency matrix

Let's say illustrate this with a community of 2 producers.

```@repl befwm2
foodweb = FoodWeb([0 0; 0 0]);
```

For this community the two possible competition links are the two interspecific links
between 1 and 2 (``1 \rightarrow 2`` and ``2 \rightarrow 1``).

You can make the producers compete
by giving a number of links (integer) to `n_competition`:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_competition=2)
```

!!! note
    As the interaction is symmetric the number of links should be even,
    if you provide an odd number, the function throws an error.

Instead of providing a number of links,
you can provide a connectance.
The syntax remains the same, but instead of giving an integer to `n_competition`
give a float:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_competition=1.0)
```

!!! note "Connectance definition"
    Here, the connectance of non-trophic interactions is not defined as
    ``C=\frac{L}{S^2}`` where ``L`` is the number of links and ``S`` the number of species.
    The connectance is defined as ``C=\frac{L}{L_\text{max}}``
    where ``L_\text{max}`` is the maximum number of possible links.
    Indeed, as only pairs of producers can compete with each other
    all species pairs are not eligible for competition (e.g. a pair of consumers).
    This definition ensures you that if you provide a connectance of `1.0`
    that you fill the adjacency matrix as much as possible,
    given the rules that govern the interaction.
    The definition applies to the four non-trophic interaction types
    with ``L_\text{max}`` depending on the non-trophic interaction considered.

Lastly, you can also provide your own custom adjacency matrix to `A_competition`.

```@repl befwm2
custom_matrix = [0 1; 1 0]; # 1 competes with 2 and reversely
multiplex_network = MultiplexNetwork(foodweb, A_competition=custom_matrix)
```

### Set the interaction intensity

In addition to the structure of competition links,
you can also customize the intensity of the competition interactions
by providing a number to `c0` (default is set to 1).
For instance, if you want to put two competition links
and set the intensity of competition to 0.1, you can do:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_competition=2, c0=0.1);
multiplex_network.competition_layer
```

## Plant facilitation

### Definition

Facilitation links are directed from any species to a plant (producer).
The facilitation is translated as
an increase of the intrinsic growth rate (``r``) of the facilitated plant.
Formally, the net growth of a facilitated plant becomes:

```math
r \rightarrow r (1 + f_0 \sum_{k \in \{\text{fac}\}} (A_\text{fac})_{ik} B_k)
```

With:

- ``f_0`` the facilitation intensity
- ``A_\text{fac}`` the adjacency matrix of facilitation links

!!! note
    The multiplicative factor due to facilitation is always greater than one,
    thus the intrinsic growth is always increased by facilitation.

### Add interactions to the [`MultiplexNetwork`](@ref)

For illustration, let's consider a community
of one producer and two consumers feeding on that single producer.

```@repl befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]);
```

Here, the potential facilitation links can happen between each of the consumer and the plant
(``2 \rightarrow 1`` and ``3 \rightarrow 1``).

To fill the facilitation layer,
you can give a number of links (integer) to `n_facilitation`.

```@repl befwm2
MultiplexNetwork(foodweb, n_facilitation=1)
```

Or give a connectance (float)  to `n_facilitation`.

```@repl befwm2
MultiplexNetwork(foodweb, n_facilitation=0.5)
```

Or give an adjacency matrix to `A_facilitation`:

```@repl befwm2
MultiplexNetwork(foodweb, A_facilitation=[0 0 0; 1 0 0; 0 0 0])
```

### Set interaction intensity

Lastly, the intensity of facilitation interactions can be changed
by specifying a value to `f0` (default set to 1).
For instance, the previous example can be rewritten:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, A_facilitation=[0 0 0; 1 0 0; 0 0 0], f0=0.5);
multiplex_network.facilitation_layer
```

## Interference between predators

### Definition

The interspecific interference between predators
can only happen between predators sharing at least one prey.
Moreover, we assume interference to be symmetric
as the [Competition for space](@ref).

The interference translates as a decrease of the consumption rates
(given by the functional response) of the interfering predators.
Formally, without interference the functional response of predator ``i``
feeding on prey ``j`` writes:

```math
F_{ij} = \frac{\omega_{ij} a_{ij} B_j^h}{1 + c_{0,\text{intra}} B_i +
\sum_{k \in \{\text{preys}\}} \omega_{ik} a_{ik} h_{t,ik} B_k^h}
```

With:

- ``\omega_{ij}`` the prey preferency of predator ``i`` on prey ``j``
- ``a_{ij}`` the attack rate of predator ``i`` on prey ``j``
- ``h`` the hill exponent
- ``c_{0,\text{intra}}`` the intraspecific competition intensity
- ``h_t`` the handling time

When the interspecific interference is present a new term is added to the denominator
of the functional response translating the effect of interference:

```math
F_{ij} = \frac{\omega_{ij} a_{ij} B_j^h}{1 + c_{0,\text{intra}} B_i +
c_{0,\text{inter}} \sum_{k \in \{\text{interf}\}} (A_\text{interf})_{ik} B_k +
\sum_{k \in \{\text{preys}\}} \omega_{ik} a_{ik} h_{t,ik} B_k^h}
```

With:

- ``c_{0,\text{inter}}`` the interspecific competition intensity
- ``A_\text{interf}`` the adjacency matrix of interference links

Concretely, the interference between predators add a positive term to the denominator
of the functional response that leads to a decrease of consumption term.

### Add interactions to the [`MultiplexNetwork`](@ref)

For illustration, let's consider two consumers (2-3) feeding on one producer (1).

```@repl befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]);
```

For this community, potential interference links can happen between species 2 and 3
(``3 \rightarrow 2`` and ``2 \rightarrow 3``).

To fill the interference layer,
you can either provide a number of links (integer) to `n_interference`.

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_interference=2)
```

!!! note
    The number of links should be even as the interference is symmetric.

Equivalently, you can provide a connectance (float) to `n_interference`.

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_interference=1.0)
```

Or you can provide an adjacency matrix to `A_interference`.

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, A_interference=[0 0 0; 0 0 1; 0 1 0])
```

### Set interaction intensity

To customize the intensity of interference interactions,
you can specify a value to `i0` (default set to 1).
For instance, you can do:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_interference=1.0, i0=0.6);
multiplex_network.interference_layer
```

## Refuge provisioning

### Definition

The last non-trophic interaction is the refuge provisioning.
Refuge provisioning correspond to the case where
a sessile species provide a refuge to a prey,
protecting that latter from its predators.
Thus this interaction is always directed from a producer to a prey.

A refuge link toward prey ``j`` translates as
a decrease of the attack rates (``a_{ij}``) of the predator ``i`` feeding on the prey ``j``.
Formally, the attack rate is modified as follow:

```math
a_{ij} \rightarrow \frac{a_{ij}}{1 + r_0 \sum_{k \in \{\text{ref}\}} (A_\text{ref})_{ik} B_k}
```

With:

- ``r_0`` the refuge interaction intensity
- ``A_\text{ref}`` the adjacency matrix of refuge links

### Add interactions to the [`MultiplexNetwork`](@ref)

For illustration, let's consider a community of
one producer eaten by an intermediate consumer
which is himself eaten by a top predator.

```@repl befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # 2 eats 1 - 3 eats 2
```

In this simple case only one refuge link is possible ``1 \rightarrow 2``.

To fill the refuge layer, you can provide a number of links (integer) to `n_refuge`

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_refuge=1)
```

Or you can provide a connectance (float) to `n_refuge`.

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_refuge=1.0)
```

Or you can provide an adjacency matrix to `A_refuge`.

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, A_refuge=[0 1 0; 0 0 0; 0 0 0])
```

### Set interaction intensity

To customize the intensity of refuge interactions,
you can specify a value to `r0` (default set to 1).
For instance, you can do:

```@repl befwm2
multiplex_network = MultiplexNetwork(foodweb, n_refuge=1.0, r0=1.3);
multiplex_network.refuge_layer
```

## Adding several non-trophic interactions simultaneously

Naturally, you can fill several non-trophic layers simultaneously.
Let's say that you have a community of two producers (1-2)
and two consumers (3-4) that feed each on both producers.

```@repl befwm2
foodweb = FoodWeb([0 0 0 0; 0 0 0 0; 1 1 0 0; 1 1 0 0]);
```

You can add two competition links and one facilitation link at the same time.

```@repl befwm2
MultiplexNetwork(foodweb, n_competition=2, n_facilitation=1)
```

Moreover, for more flexibility, you can mix the different filling methods
(number of links, connectance, adjaceny matrix).
Keeping the same community,
let's assume that you want all producers to compete (`n_competition=1.0`),
one facilitation link (`n_facilitation=1`),
and the interference links between predators to occur according to a given adjacency matrix
(`A_interference=[0 0 0 0; 0 0 0 0; 0 0 0 1; 0 0 1 0]`).
To create such [`MultiplexNetwork`](@ref) you can do:

```@repl befwm2
A_i = [0 0 0 0; 0 0 0 0; 0 0 0 1; 0 0 1 0]; # prepare interference adjacency matrix
MultiplexNetwork(foodweb, n_competition=1.0, n_facilitation=1, A_interference=A_i)
```

!!! warning
    This design allow you to flexibly create your multiplex network.
    However this flexibility come at a cost:
    you should be careful about the type of the `n_...`
    arguments because floats are interpreted as a connectances
    and an integers as numbers of links.
    `MultiplexNetwork(foodweb, n_facilitation=1)` is very different from
    `MultiplexNetwork(foodweb, n_facilitation=1.0)`.
    The first reads *'put one facilitation link'*
    whereas the second reads *'put facilitation links as much as possible'*.

In the next part, you will se how to parametrize the system
given the network of your community (either a [`FoodWeb`](@ref)
or a [`MultiplexNetwork`](@ref)).
