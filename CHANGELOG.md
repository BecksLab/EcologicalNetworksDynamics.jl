# Version 0.2.1

## Breaking changes

- Components and blueprints are now two separate type hierachies.
- Components are singletons types
  whose fields are blueprint types expanding into themselves.
- Components can be directly called
  to transfer input to correct blueprint constructors
- Blueprints typically have different types based on their inputs.

```jl
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

- Model properties are now typically namespaced to ease future extensions.
- Equivalent `get_*` and `set_*!` methods may still exist
  but they are no longer exposed or recommended.
```jl
julia> m = Model(Species(3))
julia> m.species.number # (no more .n_species)
3
julia> m.species.names == [:s1, :s2, :s3]
true
```

## New features

- Model properties available with `<tab>`-completion within the REPL.
