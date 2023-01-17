# Design a data structure behaving like a julia's Dict{Symbol, T},
# but alternate references can be given as a key, aka key aliases.
# Constructing the type requires providing aliases specifications,
# under the form of an 'AliasingSystem'.
# Terminology:
#   - "reference": anything given by user to access data in the structure.
#   - "standard": the actual key used to store the data
#   - "alias": non-standard key possibly used to access the data.
# The structure should protect from ambiguous aliasing specifications.

"""
(not exported, so we need these few `BEFWM2.` adjustments in doctest)

```jldoctest
julia> import BEFWM2: OrderedCollections.OrderedDict

julia> import BEFWM2: AliasingSystem, create_aliased_dict_type, AliasingError

julia> import BEFWM2: standards, references, aliases, standardize

julia> import BEFWM2: name, is, isin, shortest

julia> al = AliasingSystem("fruit", (:apple => [:ap, :a], :pear => [:p, :pe]));

julia> length(al)
2

julia> [s for s in standards(al)]  # Original order is conserved.
2-element Vector{Symbol}:
 :apple
 :pear

julia> [r for r in references(al)]  # Shortest then lexicographic.
6-element Vector{Symbol}:
 :a
 :ap
 :apple
 :p
 :pe
 :pear

julia> aliases(al)  # Cheat-sheet.
OrderedDict{Symbol, Vector{Symbol}} with 2 entries:
  :apple => [:a, :ap]
  :pear  => [:p, :pe]

julia> name(al)
"fruit"

julia> standardize('p', al), standardize(:ap, al)
(:pear, :apple)

julia> is(:pe, :pear, al), is(:a, :pear, al)  # Test references equivalence.
(true, false)

julia> isin(:p, (:pear, :apple), al)          # Find in iterable.
true

julia> shortest(:apple, al)
:a

julia> standardize(:xy, al)
ERROR: AliasingError("Invalid fruit name: 'xy'.")
[...]

julia> AliasingSystem("fruit", ("peach" => ['p', 'h'], "pear" => ['r', 'p']))
ERROR: AliasingError("Ambiguous fruit reference: 'p' either means 'peach' or 'pear'.")
[...]

julia> AliasingSystem("fruit", ("peach" => ['h', 'e'], "pear" => ['p', 'p']))
ERROR: AliasingError("Duplicated fruit alias for 'pear': 'p'.")
[...]
```
"""
struct AliasingSystem
    # {standard ↦ [ref, ref, ref..]} with refs sorted by length then lexicog.
    _references::OrderedDict{Symbol,Vector{Symbol}} # Standards are ordered by user.
    # {reference ↦ standard}
    _surjection::Dict{Symbol,Symbol}
    # What kind of things are we referring to?
    name::String

    # Construct from a non-sorted aliases dict.
    function AliasingSystem(name, g)
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
                        throw(AliasingError("Duplicated $name alias for '$std': '$ref'."))
                    end
                    throw(
                        AliasingError(
                            "Ambiguous $name reference: " *
                            "'$ref' either means '$target' or '$std'.",
                        ),
                    )
                end
                surjection[ref] = std
            end
        end
        new(references, surjection, name)
    end
end
struct AliasingError <: Exception
    message::String
end
Base.length(a::AliasingSystem) = Base.length(a._references)
# Access copies of underlying aliasing information.
# (not actual references: we do *not* want the alias system to be mutated)
name(a::AliasingSystem) = string(a.name)
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
    throw(AliasingError("Invalid $(a.name) name: '$ref'."))
end
# Get all alternate references.
references(ref, a::AliasingSystem) = (r for r in a._references[standardize(ref, a)])
# Get first alias (shortest + earliest lexically).
shortest(ref, a::AliasingSystem) = first(references(ref, a))
# Match reference to others, regardless of aliasing.
is(ref_a, ref_b, a::AliasingSystem) = standardize(ref_a, a) == standardize(ref_b, a)
isin(ref, refs, a::AliasingSystem) =
    any(standardize(ref, a) == standardize(r, a) for r in refs)


"""
Generate an "AliasDict" type, with all associated methods, from an aliasing system.

```jldoctest AliasDict
julia> import BEFWM2: OrderedCollections.OrderedDict

julia> import BEFWM2: AliasingError, create_aliased_dict_type, AliasingError

julia> import BEFWM2: standards, references, aliases, standardize

julia> import BEFWM2: name, is, isin, shortest

julia> create_aliased_dict_type(:FruitDict, "fruit", (:apple => [:a], :berry => [:b, :br]))

julia> import BEFWM2: FruitDict #  (not exported)

julia> FruitDict()
BEFWM2.FruitDict{Any}()

julia> d = FruitDict(:a => 5, :b => 8.0)  # Mimick Dict constructor.
FruitDict{Real} with 2 entries:
  :apple => 5
  :berry => 8.0

julia> d = FruitDict(:a => 5, :b => 8.0, :berry => 7.0) #  Guard against ambiguities.
ERROR: AliasingError("Fruit type 'berry' specified twice: once with 'b' and once with 'berry'.")
[...]

julia> d = FruitDict(; a = 5, b = 8.0)  # Take advantage of Symbol indexing to use this form.
FruitDict{Real} with 2 entries:
  :apple => 5
  :berry => 8.0

julia> d = FruitDict(; b = 5, a = 8.0)  # Entries are (re)-ordered to standard order.
FruitDict{Real} with 2 entries:
  :apple => 8.0
  :berry => 5

julia> d[:a], d[:apple], d['a'], d["apple"]   # Index with anything consistent.
(8.0, 8.0, 8.0, 8.0)

julia> d[:a] = 40; #  Set values.
       d[:apple]
40

julia> haskey(d, :b), haskey(d, :berry)
(true, true)

julia> length(d)  # Still, no superfluous value is stored.
2

julia> d[:xy] = 50   # Guard against inconsistent entries.
ERROR: AliasingError("Invalid fruit name: 'xy'.")
[...]

julia> [r for r in references(d)]  # Access AliasingSystem methods from the instance..
5-element Vector{Symbol}:
 :a
 :apple
 :b
 :br
 :berry

julia> :b in references(d), :xy in references(FruitDict)  # .. or from the type itself.
(true, false)

julia> name(d), name(FruitDict)
("fruit", "fruit")

julia> shortest(:berry, d), shortest(:berry, FruitDict)
(:b, :b)

julia> standardize(:br, d), standardize(:apple, FruitDict)
(:berry, :apple)

julia> [r for r in references(:br, d)]
3-element Vector{Symbol}:
 :b
 :br
 :berry
```
"""
function create_aliased_dict_type(type_name, system_name, g)
    DictName = Symbol(type_name)

    # Mutable, but protected here as a mute variable within this function.
    alias_system = AliasingSystem(system_name, g)

    eval(
        quote

            # A "newtype" pattern just wrapping a plain Dict.
            struct $DictName{T} <: AbstractDict{Symbol,T}
                _d::Dict{Symbol,T}

            end

            # Defer basic interface to the interface of dict.
            Base.length(adict::$DictName) = length(adict._d)
            Base.merge(a::$DictName, b::$DictName) = $DictName(merge(a._d, b._d))
            Base.iterate(adict::$DictName) = Base.iterate(adict._d)
            Base.iterate(adict::$DictName, state) = Base.iterate(adict._d, state)
            Base.haskey(adict::$DictName, ref) =
                Base.haskey(adict._d, standardize(ref, adict))
            Base.:(==)(a::$DictName, b::$DictName) = a._d == b._d

            # Correct data access with aliasing ystem.
            Base.getindex(adict::$DictName, ref) =
                (Base.getindex(adict._d, standardize(ref, $alias_system)))
            Base.setindex!(adict::$DictName, v, ref) =
                (Base.setindex!(adict._d, v, standardize(ref, $alias_system)))

            # Construct.
            $DictName{T}() where {T} = $DictName{T}(Dict{Symbol,T}())
            $DictName(args...) = $DictName((k => v) for (k, v) in args)
            $DictName(; args...) = $DictName((k => v) for (k, v) in args)
            function $DictName(g::Base.Generator)
                T = pair_second_type(Dict(g))
                d = Dict{Symbol,T}()
                # Guard against redundant/ambiguous specifications.
                norm = Dict() #  standard => ref
                for (ref, value) in g
                    standard = standardize(ref, $alias_system)
                    if standard in keys(norm)
                        aname = titlecase($alias_system.name)
                        throw(
                            AliasingError(
                                "$aname type '$standard' specified twice: " *
                                "once with '$(norm[standard])' " *
                                "and once with '$ref'.",
                            ),
                        )
                    end
                    norm[standard] = ref
                    d[standard] = value
                end
                $DictName{T}(d)
            end

            # Access underlying AliasingSystem information.
            for (fn, first_args) in [
                (:name, [()]),
                (:standards, [()]),
                (:aliases, [()]),
                (:references, [(), (:ref,)]),
                (:standardize, [(:ref,)]),
                (:shortest, [(:ref,)]),
                (:is, [(:ref_a, :ref_b)]),
                (:isin, [(:ref, :refs)]),
            ]
                for code in [
                        # Versions from the raw unspecialized type.
                        :($fn(::Type{$$DictName}) where {} = $fn($$alias_system)),
                        # Versions from the specialized type.
                        :($fn(::Type{$$DictName{T}}) where {T} = $fn($$alias_system)),
                        # Versions from an instance.
                        :($fn(::$$DictName{T}) where {T} = $fn($$DictName)),
                    ],
                    fargs in first_args

                    for a in fargs
                        insert!(code.args[1].args[1].args, 2, a)
                        insert!(code.args[2].args[2].args, 2, a)
                    end
                    eval(code)
                end
            end

        end,
    )
end
# Utility to the above.
pair_second_type(::Dict{A,B}) where {A,B} = B
