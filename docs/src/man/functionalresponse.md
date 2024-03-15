# How to choose the functional response?

```@setup befwm2
using BEFWM2
```

The functional response quantifies the consumption rates of resources by consumers.
There are different types of functional response (*e.g.*, linear, classic or bioenergetic)
and changing functional response type can drastically change the model dynamics.
Below we describe the functional response types implemented in this package
and how you can change from one functional response to another.

The functional responses are ordered by increasing complexity.
First, we begin with the [Linear response](@ref)
which is the most simple response we can think of.
Then, we present two more complex responses,
the [Bioenergetic response](@ref) and the [Classic response](@ref),
that both take into account a saturation effect with the resource biomass.

## Linear response

The linear response states that the consumption rate of the consumer is
proportional to the biomass of the resource.
Such an assumption is biologically wrong for large resource biomass,
as there is no saturation effect.
However, the major advantage of the linear response is that
it makes theoretical derivations easy.
For that reason, we find it in many theoretical models (e.g. Lotka-Volterra).

The linear response for consumer ``i`` eating resource ``j`` writes:

```math
F_{ij} = \omega_{ij} \alpha_i B_j
```

with:

  - ``B_j`` the biomass of resource ``j``
  - ``\alpha_{i}`` the consumption rate of predator ``i``
  - ``\omega_{ij}`` preferency of consumer ``i`` on resource ``j``

The linear response and its parameters
can be accessed by calling the [`LinearResponse`](@ref) method
with the [`FoodWeb`](@ref) as a mandatory argument.

```@example befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # 1 producer ⋅ 2 eats 1 ⋅ 3 eats 2
f = LinearResponse(foodweb);
f.ω # preferency
f.α # consumption rate
```

Above parameters take default values, but you can specify custom values.
For instance if you want to double the attack rate of predator 3, you can do:

```@example befwm2
f = LinearResponse(foodweb; α = [0.0, 1.0, 2.0]);
f.α # custom attack rates
```

In addition to storing the functional response parameters,
the [`LinearResponse`](@ref) method can be used as a function
corresponding to the linear functional response.
To do so, you just need to provide the species biomass vector (`B`),
where `B[i]` is the biomass of species ``i``.

```@example befwm2
f = LinearResponse(foodweb);
B = [1, 1, 1]; # defining species biomass
f(B) # F matrix, F[i,j] = Fᵢⱼ
```

And the corresponding ODEs system is:

```math
\frac{dB_i}{dt} = g(B_i)
    + B_i \sum_{j \in \{ \text{res.} \}} e_{ij} F_{ij}
    - \sum_{j \in \{ \text{cons.} \}} B_j F_{ji}
    - x_i B_i
```

The first term is a growth term (*e.g.* logistic growth)
that is non-zero only for producers.
The second term translates the biomass gained by eating resources,
with ``e_{ij}`` the assimilation efficiency.
The third term translates the biomass loss by being eaten by consumers.
The fourth term quantifies the biomass loss due to the species metabolic demand (``x_i``).

If the linear response can be useful in simple cases,
it is probably better for you to consider one of the two following responses
which are more biologically realistic
as they consider a saturation effect with resource biomass.

## Bioenergetic response

The bioenergetic response was first introduced by
[Yodzis and Innes (1992)](https://www.journals.uchicago.edu/doi/abs/10.1086/285380).
It assumes that the consumption rate saturates for large resource biomass.

Formally, the bioenergetic response is written:

```math
F_{ij} = \frac{\omega_{ij} B_j^h}{B_0^h + c_i B_i B_0^h
    + \sum_{k \in \{ \text{res.} \}} \omega_{ik} B_k^h}
```

with:

  - ``\omega_{ij}`` preferency of consumer ``i`` on resource ``j``
  - ``B_0`` the half-saturation density
  - ``c_i`` the intensity of intraspecific predator interference
  - ``h`` the hill-exponent

!!! note
    
      - ``\lim_{B_j \to +\infty} F_{ij} = 1``
    
      - ``F_{ij}(B_0) = \frac{1}{2}`` if considering a consumer feeding only one resource
        and no predator interference (``c_i=0``),
        hence the name 'half-saturation density' for ``B_0``.

The bioenergetic response and its parameters
can be accessed by calling the [`BioenergeticResponse`](@ref) method
with the [`FoodWeb`](@ref) as a mandatory argument.

```@example befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # 1 producer ⋅ 2 eats 1 ⋅ 3 eats 2
f = BioenergeticResponse(foodweb);
f.ω # preferency
f.B0 # half-saturation
f.c # interference intensity
f.h # hill exponent
```

Above parameters take default values, but you can specify custom values.
For instance if you want to set the hill exponent (`h`) to 1 instead of 2, you can do:

```@example befwm2
f = BioenergeticResponse(foodweb; h = 1);
f.h # custom hill exponent
```

In addition to storing the functional response parameters,
the [`BioenergeticResponse`](@ref) method can be used as a function
corresponding to the bioenergetic functional response.
To do so, you just need to provide the species biomass vector (`B`),
where `B[i]` is the biomass of species ``i``.

```@example befwm2
f = BioenergeticResponse(foodweb);
B = [1, 1, 1]; # defining species biomass
f(B) # F matrix, F[i,j] = Fᵢⱼ
```

The corresponding system of ODEs is:

```math
\frac{dB_i}{dt} = g(B_i)
    + B_i x_i y_i \sum_{j \in \{ \text{res.} \}} F_{ij}
    - \sum_{j \in \{ \text{cons.} \}} \frac{B_j x_j y_j F_{ji}}{e_{ij}}
    - x_i B_i
```

We have the same terms than for the [Linear response](@ref),
from left to right: growth, gain by eating, loss by being eaten and metabolic loss.
The only difference is that we have introduce ``y_i``
which is the maximum consumption rate of consumer i relative to its metabolic rate ``x_i``.

An alternative to the bioenergetic response,
when considering a response with a saturation effect,
is the classic response that we present in the next section.

## Classic response

This functional response is said to be 'classic' as it was the first one
(excepting the linear response) to be used.
It was first developed by [Holling in 1959](https://doi.org/10.4039/Ent91385-7).
Moreover, the classic response is equivalent to the [Bioenergetic response](@ref),
however the parametrization is slightly different.
To see how we can go from one to the other,
see [Williams et al. 2007](https://doi.org/10.1007/978-1-4020-5337-5_2).

Formally the classic response is written:

```math
F_{ij} = \frac{1}{m_i} \cdot
    \frac{\omega_{ij} a_{ij} B_j^h}{1 + c_i B_i
    + h_t \sum_{k \in \{ \text{res.} \}} \omega_{ik} a_{ik} B_k^h}
```

with:

  - ``\omega_{ij}`` preferency of consumer ``i`` on resource ``j``
  - ``c_i`` the intensity of intraspecific predator interference
  - ``h`` the hill-exponent
  - ``a_{ij}`` the attack rate of consumer ``i`` on resource ``j``
  - ``h_t`` the handling time
  - ``m_i`` the body mass of consumer ``i``

The classic response and its parameters
can be accessed by calling the [`ClassicResponse`](@ref) method
with the [`FoodWeb`](@ref) as a mandatory argument.

```@example befwm2
foodweb = FoodWeb([0 0 0; 1 0 0; 0 1 0]); # 1 producer ⋅ 2 eats 1 ⋅ 3 eats 2
f = ClassicResponse(foodweb);
f.ω # preferency
f.c # interference intensity
f.aᵣ # attack rate
f.h # hill exponent
f.hₜ # handling time
```

Above parameters take default values, but you can specify custom values.
For instance if you want to set the handling time (`h`) to 0.1 instead of 1, you can do:

```@example befwm2
f = ClassicResponse(foodweb; hₜ = 0.1);
f.hₜ # custom handling time
```

In addition to storing the functional response parameters,
the [`ClassicResponse`](@ref) method can be used as a function
corresponding to the classic functional response.
To do so, you just need to provide the species biomass vector (`B`),
where `B[i]` is the biomass of species ``i``.

```@example befwm2
f = ClassicResponse(foodweb);
B = [1, 1, 1]; # defining species biomass
f(B, foodweb) # F matrix, F[i,j] = Fᵢⱼ
```

The corresponding system of ODEs is:

```math
\frac{dB_i}{dt} = g(B_i)
    + B_i \sum_{j \in \{ \text{res.} \}} e_{ij} F_{ij}
    - \sum_{j \in \{ \text{cons.} \}} B_j F_{ji}
    - x_i B_i
```

We have the same terms than for the [Linear response](@ref)
and the [Classic response](@ref),
from left to right: growth, gain by eating, loss by being eaten and metabolic loss.
