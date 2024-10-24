# Version 0.2.1

## Breaking changes

- Components and blueprints are now two separate type hierachies.
- Components are singletons types
  whose fields are blueprint types expanding into themselves.
- Components can be directly called
  to transfer input to correct blueprint constructors
- Blueprints typically have different types based on their inputs.

  ```julia
  julia> Species
  Species (component for <internals>, expandable from:
    Names: raw species names,
    Number: number of species,
  )
  julia> Species(5) isa Species.Number
  true
  julia> Species(["a", "b", "c"]) isa Species.Names
  true
  ```

  This comes with minor incompatible changes
  to the available set of blueprint constructor methods.
  For instance the redundant form
  `BodyMass(M = [1, 2])` is not supported anymore,
  but `BodyMass([1, 2])` does the same
  and `BodyMass(Z = 1.5)` still works as expected.

- Model properties are now typically namespaced to ease future extensions.
- Equivalent `get_*` and `set_*!` methods may still exist
  but they are no longer exposed or recommended:
  use direct property accesses instead.
  ```julia
  julia> m = Model(Species(3))
  julia> m.species.number # (no more `.n_species` or `get_n_species(m)`)
  3
  julia> m.species.names == [:s1, :s2, :s3]
  true
  ```

- Some property names have changed. The following list is not exhaustive,
  but new names can easily be discovered using REPL autocompletion
  or the `properties(m)` and `properties(m.prop)` methods:
  - `model.trophic_links` becomes `model.trophic.matrix`,
    because it does yield a matrix and not some collection of "links".
    The alias `model.A` is still available.
  - Likewise,
    `model.herbivorous_links` becomes `model.trophic.herbivory_matrix` *etc.*

## New features

- Model properties available with `<tab>`-completion within the REPL.

- Every blueprint *brought* by another is available as a brought field
  to be either *embedded*, *implied* or *unbrought*:
  ```julia
  julia> fw = Foodweb.Matrix([0 0; 1 0]) # Implied (brought if missing).
  blueprint for <Foodweb>: Matrix {
    A: 1 trophic link,
    species: <implied blueprint for <Species>>,
  }
  julia> fw.species = [:a, :b]; # Embedded (brought, erroring if already present).
         fw
  blueprint for <Foodweb>: Matrix {
    A: 1 trophic link,
    species: <embedded blueprint for <Species>: Names {
      names: [:a, :b],
    }>,
  }
  julia> fw.species = nothing; # Unbrought (error if missing).
         fw
  blueprint for <Foodweb>: Matrix {
    A: 1 trophic link,
    species: <no blueprint brought>,
  }
  ```

- Every "leaf" "geometrical" model property *i.e.* a property whose futher
  model topology does not depend on or is not planned to depend on
  is now writeable.
  ```julia
  julia> m = Model(fw, BodyMass(2));
         m.M[1] *= 10;
         m.M == [20, 2]
  true
  ```

- Values are checked prior to expansion:
  ```julia
  julia> m = Model(fw, Efficiency(1.5))
  TODO
  ```

- Efficiency from a matrix implies a Foodweb.
  ```julia
  julia> e = 0.5;
         m = Model(fw, Efficiency([
            0 e e
            0 0 e
            e 0 0
         ]))
  TODO
  ```
