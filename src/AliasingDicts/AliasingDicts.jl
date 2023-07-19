module AliasingDicts

using OrderedCollections
using StringCases
import ..Option

# Design a data structure behaving like a julia's Dict{Symbol, T},
# but alternate references can be given as a key, aka key aliases.
# Constructing the type requires providing aliases specifications,
# under the form of an 'AliasingSystem'.
# Terminology:
#   - "reference": anything given by user to access data in the structure.
#   - "standard": the actual key used to store the data
#   - "alias": non-standard key possibly used to access the data.
# The structure should protect from ambiguous aliasing specifications.
#
# TODO: AliasingSystem should be defined \
# along with a `struct `Enum` s::Symbol end` \
# only accepting valid symbols values,
# and conveniently used as keys.

# ==========================================================================================
# The aliasing system is the value taking care
# of bookeeping aliases, references and standards.

struct AliasingSystem
    # {standard ↦ [ref, ref, ref..]} with refs sorted by length then lexicog.
    _references::OrderedDict{Symbol,Vector{Symbol}} # Standards are ordered by user.
    # {reference ↦ standard}
    _surjection::Dict{Symbol,Symbol}
    # What kind of things are we referring to?
    # (useful for error messages and code generation)
    name::String
    shortname::Symbol

    # Construct from a non-sorted aliases dict.
    function AliasingSystem(name, shortname, g)
        err(mess) = throw(AliasingError(name, mess))
        references = OrderedDict()
        surjection = Dict()
        for (std, aliases) in g
            std = Symbol(std)
            refs = vcat([Symbol(a) for a in aliases], [std])
            references[std] = sort!(sort!(refs); by = x -> length(string(x)))
            for ref in refs
                # Protect from ambiguity.
                if ref in keys(surjection)
                    target = surjection[ref]
                    if target == std
                        err("Duplicated $name alias for '$std': '$ref'.")
                    end
                    err(
                        "Ambiguous $name reference: " *
                        "'$ref' either means '$target' or '$std'.",
                    )
                end
                surjection[ref] = std
            end
        end
        new(references, surjection, name, shortname)
    end
end

Base.length(a::AliasingSystem) = Base.length(a._references)

# Access copies of underlying aliasing information.
# (not actual references: we do *not* want the alias system to be mutated)
name(a::AliasingSystem) = a.name
shortname(a::AliasingSystem) = a.shortname
standards(a::AliasingSystem) = (r for r in keys(a._references))
references(a::AliasingSystem) = (r for refs in values(a._references) for r in refs)

# One cheat-sheet with all standards, their order and aliases.
aliases(a::AliasingSystem) =
    OrderedDict(s => [r for r in references(s, a) if r != s] for s in standards(a))
function standardize(ref, a::AliasingSystem)
    key = Symbol(ref)
    if key in references(a)
        return a._surjection[key]
    end
    throw(AliasingError(a.name, "Invalid $(a.name) name: '$ref'."))
end

# Get all alternate references.
references(ref, a::AliasingSystem) = (r for r in a._references[standardize(ref, a)])

# Get first alias (shortest + earliest lexically).
shortest(ref, a::AliasingSystem) = first(references(ref, a))

# Match reference to others, regardless of aliasing.
is(ref_a, ref_b, a::AliasingSystem) = standardize(ref_a, a) == standardize(ref_b, a)
isin(ref, refs, a::AliasingSystem) =
    any(standardize(ref, a) == standardize(r, a) for r in refs)

# ==========================================================================================
# The actual aliasing dict type internally refers to one aliasing system to work.
abstract type AliasingDict{T} <: AbstractDict{Symbol,T} end

# Defer basic interface to the interface of dict,
# assuming all subtypes are of the form:
#  struct Sub <: AliasingDict{T}
#      _d::Dict{Symbol,T}
#  end
Base.haskey(a::AliasingDict, k) = Base.haskey(a._d, standardize(k, a))
Base.getindex(a::AliasingDict, k) = Base.getindex(a._d, standardize(k, a))
Base.setindex!(a::AliasingDict, k, v) = Base.setindex!(a._d, standardize(k, a), v)
Base.get(a::AliasingDict, k, d) = Base.get(a._d, standardize(k, a), d)
Base.get!(a::AliasingDict, k, d) = Base.get!(a._d, standardize(k, a), d)
Base.get(f, a::AliasingDict, k) = Base.get(f, a._d, standardize(k, a))
Base.get!(f, a::AliasingDict, k) = Base.get!(f, a._d, standardize(k, a))
Base.pop!(a::AliasingDict, k) = Base.pop!(a._d, standardize(k, a))
Base.pop!(a::AliasingDict, k, d) = Base.pop!(a._d, standardize(k, a), d)
Base.length(a::AliasingDict) = length(a._d)
Base.merge(a::AliasingDict, b::AliasingDict) = AliasingDict(merge(a._d, b._d))
Base.iterate(a::AliasingDict) = Base.iterate(a._d)
Base.iterate(a::AliasingDict, state) = Base.iterate(a._d, state)
Base.:(==)(a::AliasingDict, b::AliasingDict) = a._d == b._d
# Forward all basic request on instances to the actual types.

# The methods for types are defined within the type definition macro.
shortname(a::AliasingDict) = shortname(typeof(a))
name(a::AliasingDict) = name(typeof(a))
standards(a::AliasingDict) = standards(typeof(a))
aliases(a::AliasingDict) = aliases(typeof(a))
references(a::AliasingDict) = references(typeof(a))
references(ref, a::AliasingDict) = references(ref, typeof(a))
standardize(ref, a::AliasingDict) = standardize(ref, typeof(a))
shortest(ref, a::AliasingDict) = shortest(ref, typeof(a))
is(ref_a, ref_b, a::AliasingDict) = is(ref_a, ref_b, typeof(a))
isin(ref, refs, a::AliasingDict) = isin(ref, refs, typeof(a))

# Generate a correct subtype for the above class,
# with the associated aliasing system.
# TODO: refresh the following code now that julia metaprog is less of a mystery.
macro aliasing_dict(DictName, system_name, shortname, g_xp)
    argerr(mess) = throw(ArgumentError(mess))

    DictName isa Symbol ||
        argerr("Not a symbol name for an aliasing dict type: $(repr(DictName)).")

    system_name isa String ||
        argerr("Not a string name for an aliasing dict type: $(repr(system_name)).")

    # The aliasing system is unfortunately mutable: do not expose to the invoker.
    alias_system = Symbol(DictName, :_alias_system)

    # Type/methods generation.
    DictName = esc(DictName)
    res = quote

        # Unexposed as unescaped here.
        $alias_system = $AliasingSystem($system_name, $shortname, $g_xp)

        # Newtype a plain dict.
        struct $DictName{T} <: $AliasingDict{T}
            _d::Dict{Symbol,T}

            # Construct from generator with explicit type.
            function $DictName{T}(::$Type{$InnerConstruct}, generator) where {T}
                d = Dict{Symbol,T}()
                # Guard against redundant/ambiguous specifications.
                norm = Dict{Symbol,Symbol}() #  standard => ref
                for (ref, value) in generator
                    standard = $standardize(ref, $alias_system)
                    if standard in keys(norm)
                        aname = titlecase($alias_system.name)
                        throw(
                            $AliasingError(
                                $system_name,
                                "$aname type '$standard' specified twice: " *
                                "once with '$(norm[standard])' " *
                                "and once with '$ref'.",
                            ),
                        )
                    end
                    norm[standard] = ref
                    d[standard] = value
                end
                new{T}(d)
            end

        end

        # Infer common type from pairs, and automatically convert keys to symbols.
        function $DictName(args::Pair...)
            g = ((Symbol(k), v) for (k, v) in args)
            $DictName{$common_type_for(g)}($InnerConstruct, g)
        end
        # Same with keyword arguments as keys, default to Any for empty dict.
        $DictName(; kwargs...) =
            if isempty(kwargs)
                $DictName{Any}($InnerConstruct, ())
            else
                $DictName{$common_type_for(kwargs)}($InnerConstruct, kwargs)
            end
        # Automatically convert keys to symbols, and values to the given T.
        $DictName{T}(args...) where {T} =
            $DictName{T}($InnerConstruct, ((Symbol(k), v) for (k, v) in args))
        # Same with keyword arguments as keys.
        $DictName{T}(; kwargs...) where {T} = $DictName{T}($InnerConstruct, kwargs)

        # Correct data access with aliasing ystem.
        # TODO: this throws KeyError(:reference) instead of KeyError(:alias).
        $Base.getindex(adict::$DictName, ref) =
            (Base.getindex(adict._d, $standardize(ref, $alias_system)))
        $Base.setindex!(adict::$DictName, v, ref) =
            (Base.setindex!(adict._d, v, $standardize(ref, $alias_system)))

    end

    # Specialize dedicated methods to access underlying AliasingSystem information.
    push_res!(quoted) = push!(res.args, quoted.args[2])
    for (fn, first_args) in [
        (:name, [()]),
        (:shortname, [()]),
        (:standards, [()]),
        (:aliases, [()]),
        (:references, [(), (:ref,)]),
        (:standardize, [(:ref,)]),
        (:shortest, [(:ref,)]),
        (:is, [(:ref_a, :ref_b)]),
        (:isin, [(:ref, :refs)]),
    ]

        fn = :($AliasingDicts.$fn)

        for fargs in first_args

            # Specialize for the UnionAll type.
            code = quote
                $fn(::Type{$DictName}) = $fn($alias_system)
            end
            for a in fargs
                insert!(code.args[2].args[1].args, 2, a)
                insert!(code.args[2].args[2].args[2].args, 2, a)
            end
            push_res!(code)

            # Specialize for the DataType.
            code = quote
                $fn(::Type{$DictName{T}}) where {T} = $fn($alias_system)
            end
            for a in fargs
                insert!(code.args[2].args[1].args[1].args, 2, a)
                insert!(code.args[2].args[2].args[2].args, 2, a)
            end
            push_res!(code)

        end

    end

    res

end
export @aliasing_dict

# Marker dispatching to the underlying constructor.
struct InnerConstruct end

# Extract the less abstract common type from the given keyword arguments.
function common_type_for(pairs_generator)
    GItem = Base.@default_eltype(pairs_generator) # .. provided I am allowed to use this?
    T = GItem.parameters[2]
    return T
end

# Dedicated exception type.
struct AliasingError <: Exception
    name::String
    message::String
end
function Base.showerror(io::IO, e::AliasingError)
    print(io, "In aliasing system for $(repr(e.name)): $(e.message)")
end

# Useful APIs can be crafted out of nesting two aliased dicts together.
include("./nested_2D_api.jl")


# ==========================================================================================
# Display.

# Compact display with only short references.
function display_short(d::AliasingDict)
    D = typeof(d)
    "($(join(("$(shortest(k, D)): $v" for (k, v) in d), ", ")))"
end

# Full display with aliases.
# Optionally indent by increasing level.
function display_long(d::AliasingDict; level = 0)
    isempty(d) && return "()"
    ind(n) = "\n" * repeat("  ", level + n)
    res = "("
    for (ref, aliases) in aliases(d)
        haskey(d, ref) || continue
        res *= ind(1) * "$ref ($(join(repr.(aliases), ", "))) => $(d[ref]),"
    end
    res * ind(0) * ")"
end

function Base.show(io::IO, d::AliasingDict{T}) where {T}
    D = typeof(d)
    print(io, "$D$(display_short(d))")
end

function Base.show(io::IO, ::MIME"text/plain", d::AliasingDict{T}) where {T}
    D = typeof(d)
    print(io, "$D$(display_long(d))")
end

end
