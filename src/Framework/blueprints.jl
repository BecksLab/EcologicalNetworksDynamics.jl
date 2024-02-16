# Blueprint expand into components within a system.

abstract type Blueprint{V} end
export Blueprint

# Every blueprint is supposed to bring exactly one major component.
# This method implements the mapping,
# and must be explicited by components devs.
componentof(::Type{B}) where {B<:Blueprint} = throw("Unspecified component for $(repr(B)).")
componentof(::B) where {B<:Blueprint} = componentof(B)

# Blueprints must be copyable, but be careful that the default (deepcopy)
# is not necessarily what component devs are after.
Base.copy(b::Blueprint) = deepcopy(b)

#-------------------------------------------------------------------------------------------
# Requirements.

# Return non-empty list if components are required
# for this blueprint to expand,
# even though the corresponding component itself would make sense without these.
expands_from(::Blueprint) = CompsReasons()
# TODO: not formally tested yet.. but maybe wait on the framework to be refactored first?

# Specify blueprints to be automatically created and expanded
# before the focal blueprint expansion their component if not present.
# Every blueprint type listed here needs to be constructible from the focal blueprint.
# If the data within the blueprint is not sufficient to imply another one,
# opt-out from this default 'true' value: implication is therefore "optional".
implies(b::Blueprint) = Iterators.filter(B -> can_imply(b, B), max_implies(b))
can_imply(::Blueprint, ::Type{<:Blueprint}) = true
max_implies(::Blueprint) = Type{<:Blueprint}[]
construct_implied(B::Type{<:Blueprint}, b::Blueprint) =
    throw("Implying '$B' from '$(typeof(b))' is unimplemented.")

# Same, but the listed blueprints are always created and expanded,
# resulting in an error if their components are already present.
embeds(::Blueprint) = Type{<:Blueprint}[]
can_embed(::Blueprint, ::Type{<:Blueprint}) = true
max_embeds(::Blueprint) = Type{<:Blueprint}[]
construct_embedded(B::Type{<:Blueprint}, b::Blueprint) =
    throw("Embedding '$B' within '$(typeof(b))' is unimplemented.")

#-------------------------------------------------------------------------------------------
# Conflicts.

# Assuming that all component addition / blueprint expansion conditions are met,
# and that brought blueprints have already been expanded,
# verify that the internal system value can still receive it.
# Framework users will use this method to verify
# that the blueprint received matches the current system state
# and that it makes sense to expand within in.
# The objective is to avoid failure during expansion,
# as it could result in inconsistent system state.
# Raise a blueprint error if not the case.
# NOTE: a failure during late check does not compromise the system state consistency,
#       but it does result in that not all blueprints brought by the focal blueprint
#       be added as expected.
#       This is to avoid the need for making the system mutable and systematically fork it
#       to possibly revert to original state in case of failure.
late_check(_, ::Blueprint) = nothing # No particular constraint to enforce by default.

# Same, but *before* brought blueprints are expanded.
# When this runs, it is guaranteed
# that there is no conflicting component in the system
# and that all required components are met,
# but, as it cannot be assumed that required components have already been expanded,
# the check should not depend on the system value.
# TODO: add formal test for this.
early_check(::Blueprint) = nothing # No particular

# The expansion step is when and the wrapped system value
# is finally modified, based on the information contained in the blueprint,
# to feature the associated component.
# This is only called if all component addition conditions are met
# and the above check passed.
# This function must not fail,
# otherwise the system ends up in a bad state.
# TODO: must it also be deterministic?
#       Or can a random component expansion happen
#       if based on consistent blueprint input and infallible.
#       Note that random expansion would result in:
#       (System{Value}() + blueprint).property != (System{Value}() + blueprint).property
#       which may be confusing.
expand!(_, ::Blueprint) = nothing # Expanding does nothing by default.

# NOTE: the above signatures for default functions *could* be more strict
# like eg. `check(::V, ::Blueprint{V}) where {V}`,
# but this would force framework users to always specify the first argument type
# or concrete calls to `check(system, myblueprint)` would be ambiguous.

# When components "optionally depend" on others,
# it may be useful to check whether they are present in the system
# within the methods above.
# To this end, an optional, additional argument
# can be received with a reference to the system,
# and can be queried for eg. `has_component(system, component)`.
# This third argument is ignored by default,
# unless in overriden methods.
late_check(v, b::Blueprint, _) = late_check(v, b)
expand!(v, b::Blueprint, _) = expand!(v, b)

# This exception error is thrown by the system guards
# before expansion of a blueprint, reporting a failure to meet the requirements.
# In particular, this is the exception expected to be thrown from the `check` method.
# Not parametrized over blueprint type because the exception is only thrown and caught
# within a controlled context where this type is known.
struct BlueprintCheckFailure <: Exception
    message::String
end
checkfails(m) = throw(BlueprintCheckFailure(m))
export BlueprintCheckFailure, checkfails
