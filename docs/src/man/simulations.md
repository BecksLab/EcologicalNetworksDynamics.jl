# How to run foodweb simulations?

```@setup befwm2
using BEFWM2
```

Once the foodweb is created (see [How to generate foodwebs?](@ref))
and the model parameters generated (see [How to generate model parameters?](@ref)),
you are ready to run the simulation of the biomass dynamics.
By default, this can be done in one line
and with no other arguments than the [`ModelParameters`](@ref)
and the initial biomass (`B0`).

```@example befwm2
foodweb = FoodWeb([0 0; 1 0]); # step 1: create the foodweb
params = ModelParameters(foodweb); # step 2: generate model parameters
B0 = [0.5, 0.5]; # set initial biomass
solution = simulate(params, B0); # step 3: run simulation
show(IOContext(stdout, :limit => true, :displaysize => (10, 10)), "text/plain", solution)
```

In the following sections we explain what is happening inside [`simulate`](@ref)
and how you can change the default arguments to suits your needs.
We begin by explaining how you can handle the time span of the simulation.

## Handle time

The dynamic of the system is simulated between t=`t0` and t=`tmax`.
By default `t0=0` and `tmax=500`.
However these values depends on the simulated system.
If your system has a fast dynamic you can decrease `tmax` value,
by contrary if your system has slow dynamic you can increase `tmax` value.

```@example befwm2
solution = simulate(params, B0; tmax = 50); # fast dynamic => decrease 'tmax'
show(IOContext(stdout, :limit => true, :displaysize => (10, 10)), "text/plain", solution)
```

Moreover we can note that trajectories are saved every `δt=0.25`.

```@example befwm2
solution.t == collect(0:0.25:50)
```

But the timestep can be changed if you want to have lower or higher time resolution.

```@example befwm2
solution = simulate(params, B0; tmax = 50, δt = 0.5); # lower time resolution
solution.t == collect(0:0.5:50)
```

!!! note
    
    `δt` does not correspond to the timesteps of the solver.
    That latter is handled automatically by the solving algorithm.
    `δt` is the timestep at which trajectory points are *saved*,
    and these points are infered with a polynamial interpolation.
    For more details see the
    [Common solver options](https://diffeq.sciml.ai/stable/basics/common_solver_opts/)
    of DifferentialEquations.jl.

In addition to the time of your simulation,
you have to care about the choice of the solving algorithm
you choose to simulate your system.

## Choice of the solver algorithm

!!! warning
    
    Work in progress.

## Extinction threshold

!!! warning
    
    Work in progress.

## Solution handling

How to manipulate the solution?
