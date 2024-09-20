# Version 0.2.1

## Breaking changes

- Components and blueprints are now two separate type hierachies.
- Components are singletons types
  whose fields are blueprint types expanding into themselves.
- Components can be directly called
  to transfer input to correct blueprint constructors

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

