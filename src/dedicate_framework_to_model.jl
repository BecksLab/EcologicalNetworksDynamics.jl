# The main value, wrapped into a System, is what we hand out to user as "the model".

# Fine-grained namespace control.
import .Framework
const F = Framework # Convenience alias for the whole components library.
import .F: add!, blueprints, components, has_component, @method, @component, System

# Direct re-exports from the framework module.
export add!, properties, blueprints, components, has_component

const Internal = Internals.ModelParameters # <- TODO: rename when refactoring Internals.
const Blueprint = F.Blueprint{Internal}
const BlueprintSum = F.BlueprintSum{Internal}
const Component = F.Component{Internal}

const Model = F.System{Internal}
export Model

# Skip _-prefixed properties.
function properties(m::Model)
    res = []
    for (name, _) in F.properties(m)
        startswith(String(name), '_') && continue
        push!(res, name)
    end
    sort!(res)
    res
end
properties(p::F.PropertySpace) = collect(imap(first, ifilter(F.properties(p)) do (name, _)
    !startswith(String(name), '_')
end))
export properties
Base.propertynames(m::Model) = properties(m)
Base.propertynames(p::F.PropertySpace{name,P,Internal}) where {name,P} = properties(p)

# Convenience macro to define property space.
macro propspace(path)
    get = Symbol(:get_, path)
    eget = esc(get)
    quote
        $eget(::Internal, s::Model) = F.@PropertySpace($path, $Internal)(s)
        F.@method $get{$Internal} read_as($path)
    end
end

# ==========================================================================================
# The above defines var"get_a.b" method names for nested properties
# to avoid possible ambiguity with `get_a_b`.
# Use this pattern for all propsace uses
# and these convenience macro to call these methods on raw values.

macro get(raw, path)
    read(:get, raw, path)
end

macro ref(raw, path)
    read(:ref, raw, path)
end

macro set!(raw, path, rhs)
    write(raw, path, rhs)
end

# Convenience idiomatic syntax:
# @get var.path.to.prop
macro get(path)
    convenience_read(__source__, :get, path)
end
macro ref(path)
    convenience_read(__source__, :ref, path)
end
function convenience_read(src, kw, path)
    err(m) = throw(AccessError(kw, m, src))
    F.is_identifier_path(path) || err("Not an access path: $(repr(path)).")
    var, path... = F.collect_path(path)
    read(kw, var, join_path(path))
end

# @set var.path.to.prop = rhs
macro set(input)
    err(m) = throw(AccessError(:set, m, __source__))
    (false) && (local path, rhs)
    @capture(input, path_ = rhs_)
    isnothing(path_) && err("Not a `path = rhs` expression: $(repr(input))")
    F.is_identifier_path(path) || err("Not an access path: $(repr(path)).")
    var, path... = reverse(F.collect_path(path))
    write(var, join_path(path), rhs)
end

function join_path(v)
    prop = last(v)
    if length(v) == 1
        prop
    else
        head = join_path(v[1:end-1])
        :($head.$prop)
    end
end

# Actual code generation.
read(kw, raw, path) = quote
    $(Symbol(kw, :_, path))($raw)
end |> esc

write(raw, path, rhs) = quote
    $(Symbol(:set_, path, :!))($raw, $rhs)
end |> esc

# Dedicated errors.
struct AccessError
    type::Symbol
    message::String
    src::LineNumberNode
end
function Base.showerror(io::IO, e::AccessError)
    print(io, "In @$(e.type) access: ")
    println(io, crayon"blue", "$(e.src.file):$(e.src.line)", crayon"reset")
    println(io, e.message)
end

# ==========================================================================================
# Display.
Base.show(io::IO, ::Type{Internal}) = print(io, "<internals>") # Shorten and opacify.
Base.show(io::IO, ::Type{Model}) = print(io, "Model")

Base.show(io::IO, ::MIME"text/plain", I::Type{Internal}) = Base.show(io, I)
Base.show(io::IO, ::MIME"text/plain", ::Type{Model}) =
    print(io, "Model $(crayon"dark_gray")(alias for $System{$Internal})$(crayon"reset")")

# ==========================================================================================

@doc """
Model is the main object that we hand out to user
which contains all the information about the underlying ecological model.

# Create a Model

The most straightforward way to create a model is to use [`default_model`](@ref).
This function only requires you to specify the trophic network.

```julia
fw = [1 => 2, 2 => 3]
model = default_model(fw)
```

This function will help you to create a model with ease,
however it relies on default values for the parameters,
which are not always suitable for your specific case,
even though extracted from the literature.

To create a model with custom parameters, you can pass
other arguments to `default_model`.

```julia
model = default_model(fw, BodyMass(; Z = 100))
```

For instance, the above example creates a model with a
body mass distribution with a predator-prey mass ratio of 100.

It is also possible to create a model manually by adding the components one by one.
First, create an empty model:

```julia
m = Model()
```

Then add your components one by one.
Note that you have to add the components in the right order, as some components depend on others.
Moreover, some components are mandatory.
Specifically, you need to provide a food web, species body masses, a functional response, metabolic rates and a producer growth function.

```julia
m = Model()
m += Foodweb([3 => 2, 2 => 1])
m += ClassicResponse(; h = 2, M = BodyMass([0.1, 2, 3]))
m += LogisticGrowth(; r = 1, K = 10)
m += Metabolism(:Miele2019)
m += Mortality(0)
```

# Read and write properties of the model

First all properties contained in the model
can be listed with:

```julia
properties(m) # Where m is a Model.
```

Then, the value of a property can be read with
`get_<X>` where `X` is the name of the property.
For instance, to read mortality rates:

```julia
get_mortality(m) # Equivalent to: m.mortality.
```

You can also re-write properties of the model using `set_<X>!`.
However, not all properties can be re-written,
because some of them are derived from the others.
For instance, many parameters are derived from species body masses,
therefore changing body masses would make the model inconsistent.
However, terminal properties can be re-written, as the species metabolic rate.
""" Model
