# The main value, wrapped into a System, is what we hand out to user as "the model".

const InnerParms = Internals.ModelParameters # <- TODO: rename when refactoring Internals.
const Model = System{InnerParms}
const ModelBlueprint = Blueprint{InnerParms}
const ModelBlueprintSum = Framework.BlueprintSum{InnerParms}
const ModelComponent = Component{InnerParms}
export Model
export has_component

# Short alias to make it easier to add methods as F.expand!(..)
# rather than Framework.expand!(..).
const F = Framework

# Willing to make use of "properties" even for the wrapped value.
Base.getproperty(v::InnerParms, p::Symbol) = Framework.unchecked_getproperty(v, p)
Base.setproperty!(v::InnerParms, p::Symbol, rhs) =
    Framework.unchecked_setproperty!(v, p, rhs)

# For some reason this needs to be made explicit?
# Compare field by field for identity.
function Base.:(==)(a::ModelBlueprint, b::ModelBlueprint)
    typeof(a) === typeof(b) || return false
    for name in fieldnames(typeof(a))
        u, v = getfield.((a, b), name)
        u == v || return false
    end
    true
end

# Skip _-prefixed properties.
function properties(s::Model)
    res = []
    for (name, _) in F.properties(s)
        startswith(String(name), '_') && continue
        push!(res, name)
    end
    sort!(res)
    res
end

# ==========================================================================================
# Display.
Base.show(io::IO, ::Type{InnerParms}) = print(io, "<inner parms>") # Shorten and opacify.
Base.show(io::IO, ::Type{Model}) = print(io, "Model")

Base.show(io::IO, ::MIME"text/plain", I::Type{InnerParms}) = Base.show(io, I)
Base.show(io::IO, ::MIME"text/plain", ::Type{Model}) =
    print(io, "Model $(crayon"dark_gray")(alias for $System{$InnerParms})$(crayon"reset")")

# Useful to override in the case "different blueprints provide the same component"?
function display_short(b::ModelBlueprint, C::Component = typeof(b))
    res = "blueprint for $C("
    res *= join(Iterators.map(fieldnames(typeof(b))) do name
        value = getfield(b, name)
        # Special-case types that would clutter output.
        res = "$name: "
        res *= if value isa AliasingDicts.AliasingDict
            AliasingDicts.display_short(value)
        elseif value isa Union{Map,Adjacency,BinMap,BinAdjacency}
            t = if value isa Union{Map,BinMap}
                "map"
            else
                "adjacency"
            end
            t * GraphDataInputs.display_short(value)
        else
            repr(value)
        end
    end, ", ")
    res * ")"
end

function display_long(b::ModelBlueprint, c::Component = typeof(b); level = 0)
    res = "blueprint for $c:"
    level += 1
    for name in fieldnames(typeof(b))
        value = getfield(b, name)
        res *= "\n" * repeat("  ", level) * "$name: "
        # Special-case types that need proper indenting
        if value isa AliasingDicts.AliasingDict
            res *= AliasingDicts.display_long(value; level)
        elseif value isa GraphDataInputs.UList
            t = if value isa GraphDataInputs.UMap
                "map"
            else
                "adjacency"
            end
            res *= t * GraphDataInputs.display_long(value; level)
        elseif value isa ModelBlueprint
            res *= display_long(value; level)
        else
            res *= repr(
                MIME("text/plain"),
                value;
                context = IOContext(IOBuffer(), :color => true),
            )
        end
    end
    res
end

Base.show(io::IO, b::ModelBlueprint) = print(io, display_short(b))
Base.show(io::IO, ::MIME"text/plain", b::ModelBlueprint) = print(io, display_long(b))
