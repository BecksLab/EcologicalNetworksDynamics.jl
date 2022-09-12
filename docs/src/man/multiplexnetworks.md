# How to generate multiplex networks?

```@setup befwm2
using BEFWM2
```

A multiplex network is a network that
contains information about several types of interactions
between a given set of species.
The interaction types are gathered by layers,
where one layer contains all the interactions of a given type.
All the layers share the same set of nodes that are the species of the community.
For example, the trophic layer is a foodweb
which contains all the information about the feeding interactions
between the species of the community.
To generate a multiplex network,
we assume that the trophic layer is the backbone of the multiplex network,
on top of which layers of other interactions
(so-called **non-trophic interactions**) are added.
For instance, one layer could contain information
about competitive interactions between species,
and another about facilitative interactions.
The resulting multiplex network would have 3 layers: trophic, competition and facilitation.

In this package, four types of non-trophic interactions are available:

- [Interference between predators](@ref)
- [Plant facilitation](@ref)
- [Competition for space](@ref)
- [Refuge provisioning](@ref)

We chose these four non-trophic interactions because
they have been shown to significantly impact the dynamics of ecological communities
(see e.g.
[Kefi et al. 2012](https://doi-org.inee.bib.cnrs.fr/10.1111/j.1461-0248.2011.01732.x),
[Kefi et al. 2016](https://doi.org/10.1371/journal.pbio.1002527),
[Miele et al. 2019](https://doi.org/10.1371/journal.pcbi.1007269)).

In the following,
after a short introduction on how to build a minimal multiplex network from a foodweb,
we go over the four types of non-trophic interactions one by one.

!!! warning "Non-trophic interactions require `ClassicResponse`
    The non-trophic interactions are only available for the functional response:
    [`ClassicResponse`](@ref).
    For more details about the different functional responses
    see [How to choose the functional response?](@ref)

## Introduction to [`MultiplexNetwork`](@ref)

As previously explained we will build a [`MultiplexNetwork`](@ref) from a [`FoodWeb`](@ref),
In other words, we will add non-trophic interactions on top of a [`FoodWeb`](@ref).
Therefore, the first step to create your first [`MultiplexNetwork`](@ref) is
to generate a [`FoodWeb`](@ref),
which is the backbone of the [`MultiplexNetwork`](@ref)
(for more details on food web generation, see [How to generate foodwebs?](@ref)).

```@example befwm2
A = [0 0 0; 1 0 0; 0 1 0]; # 1 <- 2 <- 3
foodweb = FoodWeb(A); # build food web from adjacency matrix
```

Now that your [`FoodWeb`](@ref) is created,
you can directly create a [`MultiplexNetwork`](@ref) as follows:

```@example befwm2
multi_net = MultiplexNetwork(foodweb);
```

As you only gave the food web to the [`MultiplexNetwork`](@ref) method
without any additional arguments,
the number of non-trophic links is set to zero.

```@example befwm2
n_links(multi_net)
```

You can see that you have as expected 2 trophic links
and 0 link for all non-trophic interactions.

The layers of the multiplex network are stored in the `layers` field.
This field is a special dictionary
because its values can be accessed either with the full key
or a alias of the key.
For instance if you want to access the trophic layer you can either use the full key...

```@example befwm2
multi_net.layers[:trophic]
```

... or an alias of the `:trophic` key (e.g. `:t`)

```@example befwm2
multi_net.layers[:t]
```

Hopefully there is a cheat-sheet to know what are the aliases of each interaction.

```@example befwm2
interaction_names()
```

Now coming back to the trophic [`Layer`](@ref), you can see that it has three fields:

- `A`: the adjacency matrix that the species pairs between which
    the interactions occur;
- `intensity`: the strength of the non-trophic interaction;
- `f`: the functional form of the non-trophic effect on the corresponding parameter
    (for more details see [Specifying non-trophic functional forms](@ref))

```@example befwm2
multi_net.layers[:facilitation].A # empty
multi_net.layers[:facilitation].intensity # 1.0 by default
multi_net.layers[:facilitation].f # (r,B_f) -> r(1+B_f) ++ of growth rate
```

Before explaining how to fill the non-trophic layers,
note that the [`MultiplexNetwork`](@ref) contains, like the [`FoodWeb`](@ref),
information about the species identities, the metabolic classes, and the body-masses:

```@example befwm2
multi_net.species; # species identities
multi_net.metabolic_class; # metabolic classes
multi_net.M; # individual body mass
```

## Specifying non-trophic layers

### General rules

There are various ways to specify non-trophic layer parameters.
The key point is to use `arguments` whose general form is
```
<parameter_name>_<interaction_name> = value
```
where `<parameter_name>` is the full name or an alias of a parameter
(e.g. `connectance` or its alias `C`)
and `<interaction_name>` is the full name or an alias of an interaction
(e.g. `facilitation` or `f`).
Thus if you want to set the connectance of the facilitation layer to `1.0` you can do:

```@example befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 1 0 0]); # 2 and 3 consumes 1
net1 = MultiplexNetwork(foodweb, connectance_facilitation=1.0); # full names
net2 = MultiplexNetwork(foodweb, C_f=1.0); # aliases
net3 = MultiplexNetwork(foodweb, C_facilitation=1.0); # full name and alias
n_links(net1)[:f] == n_links(net2)[:f] == n_links(net3)[:f]
```

As for the interactions, there is a cheat-sheet to retrieve the aliases
of the [`MultiplexNetwork`](@ref) parameters.

```@example befwm2
multiplex_network_parameters_names()
```

Moreover if you want to specify the same parameters
for two or more interaction you can group them as follow

```@example befwm2
net1 = MultiplexNetwork(foodweb, C=(facilitation=0.5, interference=1.0));
```

Here we have set the connectance of the facilitation and interference layer
to `0.5` and `1.0` respectively.
This is equivalent to

```@example befwm2
net2 = MultiplexNetwork(foodweb, C_facilitation=0.5, C_interference=1.0);
n_links(net1) == n_links(net2) # both ways are equivalent
```

Reversely if you want to specify two or more parameters for the same interaction
you can group them as follow

```@example befwm2
net1 = MultiplexNetwork(foodweb, facilitation=(C=0.5, intensity=0.1));
```

Here we have set the connectance and the intensity of the facilitation layer
to `0.5` and `0.1` respectively.
This is equivalent to

```@example befwm2
net2 = MultiplexNetwork(foodweb, C_facilitation=0.5, intensity_facilitation=0.1);
n_links(net1) == n_links(net2) # both ways are equivalent
```

### Specifying the structure of non-trophic interaction layers

*The structure of the trophic layer cannot be specified,*
*because that latter is given*
*by the adjacency of the [`FoodWeb`](@ref).*
*Thus you can only specify the structure of non-trophic interactions.*

For each non-trophic interaction there are 3 ways to define the structure of the layer,
either with the:

- adjacency matrix
- connectance
- number of links

!!! note
    If either a number of links or the connectance is provided,
    the layer is filled randomly.

For a given interaction, you can only choose one of these methods because
only one of these 3 parameters is sufficient to describe the structure.
For instance it does not make sense to
define the connectance *and* the number of links of the same layer.
Thus if you don't respect this rule an error will be thrown.

```jldoctest befwm2; setup = :(using BEFWM2; foodweb=FoodWeb([0 0; 0 1]))
julia> MultiplexNetwork(foodweb, facilitation=(C=0.5, L=2))
ERROR: ArgumentError: Ambiguous specifications for facilitation matrix adjacency: both connectance ('C' within a 'facilitation' argument) and number_of_links ('L' within a 'facilitation' argument) have been specified. Consider removing one.
```

!!! note "Definition of connectance"
    Here, the connectance of non-trophic interactions is not defined as
    ``C=\frac{L}{S^2}`` where ``L`` is the number of competitive links
    and ``S`` the total number of species in the community.
    Instead, connectance is defined as ``C=\frac{L}{L_\text{max}}``
    where ``L_\text{max}`` is the maximum number of possible competitive links
    in the community.
    Indeed, as only pairs of sessile species can compete with each other,
    all species pairs are not eligible for competition (e.g. a pair of mobile species).
    This definition ensures you that if you provide a connectance of `1.0`,
    the adjacency matrix will be filled as much as possible,
    given the rules that govern the interaction.
    The definition applies to the four non-trophic interaction types
    with ``L_\text{max}`` depending on the non-trophic interaction considered.


### Specifying the intensity of non-trophic layers

To change the intensity `value` simply specify `intensity_<interaction_name>=value`.
For instance if you want to set the intensity of refuge interactions to `2.0` you can do

```@example befwm2
multi_net = MultiplexNetwork(foodweb, intensity_refuge=2.0);
multi_net.layers[:refuge].intensity
```

But you can also use aliases either for the interaction (`refuge`)
or the parameter (`intensity`), for instance

```@example befwm2
multi_net1 = MultiplexNetwork(foodweb, intensity_r=2.0);
multi_net2 = MultiplexNetwork(foodweb, I_r=2.0);
multi_net1.layers[:refuge].intensity == multi_net2.layers[:refuge].intensity == 2.0
```

!!! note "Aliases of `intensity`"
    Aliases of `intensity` parameter can be accessed with
    `multiplex_network_parameters_names()[:intensity]`.

In the following we go over each non-trophic interactions in more details.
Specifically, we explain
how they are translated in the ODEs equations and
what are the assumptions underlying them.

## Competition for space

### Definition of competition

Competition for space happens between sessile species (mostly producers).
As for the [Interference between predators](@ref),
competition is assumed to be symmetric,
i.e. if species ``i`` competes with species ``j``
then species ``j`` competes with species ``i``.
In other words, the adjacency matrix of competition links is symmetric.

Competition for space leads to a decrease of net the growth rates
of the competing species.
Formally, we define the net growth rate as:

```math
G_\text{net} = r_i G_i + \sum_{j \in \{\text{preys}\}} e_{ij} F_{ij} - x_i
```

Where:

- ``r_i G_i`` is the growth term for producers
- ``\sum_{j \in \{\text{preys}\}} e_{ij} F_{ij}`` is the biomass gained by species ``i``
    due to consumption of prey
- ``x_i`` is the metabolic loss of species ``i``

When competition occurs and if ``G_\text{net}`` is positive, then ``G_\text{net}`` becomes:

```math
G_\text{net} \rightarrow G_\text{net} (1 - c_0 \sum_{k \in \{\text{comp}\}} (A_\text{comp})_{ik} B_k)
```

With:

- ``A_\text{comp}`` the adjacency matrix of competition links
- ``c_0`` the intensity of competition
- ``B_k`` the biomass of species ``k``

!!! note "Case of negative net growth rates"
    If ``G_\text{net}`` is negative, even if a competition link is present,
    ``G_\text{net}`` is unchanged.

### Example of a community with competition interactions

Let's create a small [`MultiplexNetwork`](@ref) that contains competition interactions.
To illustrate let's use the apparent competition module (1 consumer feeding on 2 plants).

```@example befwm2
comp_module = FoodWeb([0 0 0; 0 0 0; 1 1 0]);
```

The possible competition interactions can occur between the two producers
i.e. species 1 and 2.
These potential links can be accessed with:

```@example befwm2
A_competition_full(comp_module)
```

!!! note "Access possible non-trophic interactions"
    More generally, to access the possible non-trophic interactions of your `foodweb`
    use `A_<interaction_name>_full(foodweb)`.

Now you can create a [`MultiplexNetwork`](@ref) including competition interactions.
For instance, if you want to add competition interactions as much as possible,
you can do

```@example befwm2
multi_net = MultiplexNetwork(comp_module, C_competition=1.0);
multi_net.layers[:competition].A == A_competition_full(comp_module)
```

Now let's say that you want to only add 1 competition link

```jldoctest befwm2; setup = :(using BEFWM2; comp_module = FoodWeb([0 0 0; 0 0 0; 1 1 0]))
julia> multi_net = MultiplexNetwork(comp_module, L_competition=1)
ERROR: ArgumentError: L should be even.
  Evaluated: L = 1
  Expected: L % 2 = 0
```

You have an error because because
the competition links are assumed by default to be symmetric
which implies that number of competition links has to be even.
If you want to change that assumption because
to add an odd number of competition links
you can simply specify `sym_competition=false`.

```@example befwm2
multi_net = MultiplexNetwork(comp_module, L_competition=1, sym_competition=false);
multi_net.layers[:competition].A # only one link
```

!!! note "Aliases of `symmetry`"
    As for the other [`MultiplexNetwork`](@ref) parameters,
    `symmetry` has aliases that you can use.
    To get them do `multiplex_network_parameters_names()[:symmetry]`.

## Plant facilitation

### Definition of facilitation

Facilitation links are directed from any species to a plant (primary producer).
Facilitation is translated as an increase in the intrinsic growth rate (``r``)
of the facilitated plant.
Formally, the net growth rate of a facilitated plant becomes:

```math
r \rightarrow r (1 + f_0 \sum_{k \in \{\text{fac}\}} (A_\text{fac})_{ik} B_k)
```

With:

- ``f_0`` the facilitation intensity
- ``A_\text{fac}`` the adjacency matrix of facilitation links

!!! note
    The multiplicative factor due to facilitation is always greater than one,
    thus the intrinsic growth is always increased by facilitation.

### Example of a community with facilitation interactions

Let's create a small [`MultiplexNetwork`](@ref) that contains competition interactions.
We can consider the food chain module (of length 3).

```@example befwm2
food_chain = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # 1 <- 2 <- 3
```

Let's have look where possible facilitation interactions can occur

```@example befwm2
A_facilitation_full(food_chain)
```

Now you can create a [`MultiplexNetwork`](@ref) that includes facilitation links.
This time let's specify the links with and adjacency matrix.
We want to have only one link which occurs from species 2 to species 1.

```@example befwm2
A_facilitation = [0 0 0; 1 0 0; 0 0 0];
multi_net = MultiplexNetwork(food_chain, A_facilitation=A_facilitation);
multi_net.layers[:facilitation].A == A_facilitation
```

!!! note "Symmetry of facilitation"
    As the facilitation interaction is not assumed to be symmetric
    you can specify an odd number of facilitation links.

## Interference between predators

### Definition of interference

The interspecific interference between predators
can only happen between predators sharing at least one prey.
Moreover, we assume interference to be symmetric,
in the same way as for [Competition for space](@ref).

Interference between predators leads to a decrease in the consumption rates
(given by the functional response) of the interfering predators.
Formally, without interference the functional response of a predator ``i``
feeding on a prey ``j`` writes:

```math
F_{ij} = \frac{\omega_{ij} a_{ij} B_j^h}{1 + c_{0,\text{intra}} B_i +
\sum_{k \in \{\text{preys}\}} \omega_{ik} a_{ik} h_{t,ik} B_k^h}
```

With:

- ``\omega_{ij}`` the preference of predator ``i`` for prey ``j``
- ``a_{ij}`` the attack rate of predator ``i`` on prey ``j``
- ``h`` the hill exponent
- ``c_{0,\text{intra}}`` the intraspecific interference intensity
- ``h_t`` the handling time

When interspecific interference is present, a new term is added to the denominator
of the functional response:

```math
F_{ij} = \frac{\omega_{ij} a_{ij} B_j^h}{1 + c_{0,\text{intra}} B_i +
c_{0,\text{inter}} \sum_{k \in \{\text{interf}\}} (A_\text{interf})_{ik} B_k +
\sum_{k \in \{\text{preys}\}} \omega_{ik} a_{ik} h_{t,ik} B_k^h}
```

With:

- ``c_{0,\text{inter}}`` the interspecific competition intensity
- ``A_\text{interf}`` the adjacency matrix of interference links

Concretely, interference between predators adds a positive term to the denominator
of the functional response that leads to a decrease in the consumption terms.

### Example of a community with interference interactions

Let's create a small [`MultiplexNetwork`](@ref) that contains interference interactions.
We can consider the exploitative competition module
(2 consumers feeding on the same resource).

```@example befwm2
exp_module = FoodWeb([0 0 0; 1 0 0; 1 0 0]);
```

The interference links can occur between the two consumers.

```@example befwm2
A_interference_full(exp_module)
```

Now you can create a [`MultiplexNetwork`](@ref)
which includes interspecific interference links.

```@example befwm2
multi_net = MultiplexNetwork(exp_module, L_i=2);
n_links(multi_net)[:interference]
```

As for competition, interference is assumed by default to be symmetric
but this can be modified.

```@example befwm2
multi_net = MultiplexNetwork(exp_module, i=(sym=false, L=1));
multi_net.layers[:interference].A
```

## Refuge provisioning

### Definition of refuge

The last non-trophic interaction is refuge provisioning.
Refuge provisioning corresponds to the case where
a sessile species provides a refuge to a prey,
protecting that latter from its predators.
Therefore, this interaction is assumed to be directed from a producer to a prey.

A refuge link toward prey ``j`` translates as
a decrease in the attack rates (``a_{ij}``) of the predator ``i`` feeding on the prey ``j``.
Formally, the attack rate is modified as follows:

```math
a_{ij} \rightarrow \frac{a_{ij}}{1 + r_0 \sum_{k \in \{\text{ref}\}} (A_\text{ref})_{ik} B_k}
```

With:

- ``r_0`` the refuge interaction intensity
- ``A_\text{ref}`` the adjacency matrix of refuge links

### Example of a community with refuge interactions

Let's create a small [`MultiplexNetwork`](@ref) that contains refuge interactions.
To illustrate, we consider the intraguild predation module.

```@example befwm2
intraguild_module = FoodWeb([0 0 0; 1 0 0; 1 1 0]);
```

In this module, the producer (species 1) can possibly provide a refuge
to the intermediate predator (species 2)
who is eaten by the top predator (species 3).

```@example befwm2
A_refuge_full(intraguild_module)
```

You can create a [`MultiplexNetwork`](@ref) that includes this refuge link.
Moreover let's say that you also want to set the intensity of refuge interaction to `3.0`.

```@example befwm2
multi_net = MultiplexNetwork(intraguild_module, r=(L=1, intensity=3.0))
```

## Specifying non-trophic functional forms

You have seen above that the non-trophic interactions are translated
in the dynamical equations by a modification of the model parameters.
For instance, a facilitation interaction change
the initially fixed growth rate of the producer (``r``)
into a function of the facilitating species biomass
(``r (1 + f_0 \sum_{k \in \{\text{fac}\}} (A_\text{fac})_{ik} B_k)``).
The default form of these functions have been set to what is written above *but*
can be customized.
For instance if you want that growth rate function becomes quadratic i.e.
``r (1 + (f_0 \sum_{k \in \{\text{fac}\}} (A_\text{fac})_{ik} B_k)^2)``
you can do

```@example befwm2
foodweb = FoodWeb([0 0; 1 0]); # define a simple food web to illustrate
custom_f(x,δx) = x*(1+δx^2) # default is x*(1+δx);
multi_net = MultiplexNetwork(foodweb, L_f=1, functional_form_facilitation=custom_f);
```

!!! note "Aliases of `functional_form`"
    `multiplex_network_parameters_names()[:functional_form]`

Some remarks on these functional forms,
they always take two arguments `x` (initial parameters)
and `δx` (by how much the parameter is changed).
We warn you when redefining these forms to ensure that they make sense,
because a inadequate form can totally destroy the consistency of your model.

!!! note "Interference functional form"
    The form of the interference interaction cannot be changed
    because the interference terms is defined by the functional response.

In the next part, you will see how to parametrize the system
given the network of your community (either a [`FoodWeb`](@ref)
or a [`MultiplexNetwork`](@ref)).
