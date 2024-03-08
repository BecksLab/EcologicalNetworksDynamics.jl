# Blueprint expand into components within a system.
#
# Blueprint may 'bring' other blueprints than themselves,
# so other components than their own,
# because they contain enough data to construct more than one component.
# This loosely feels like "sub-components", although it is more subtle.
# There are two ways for blueprints bring each other:
#
#   - Either they 'embed' other blueprints as sub-blueprints,
#     which expand as part of their own expansion process.
#     It is an error to embed a blueprint for a component already in the system.
#
#   - Or they 'imply' other blueprints for designated components,
#     which could be calculated from the data they contain if needed.
#     This does not need to happen if the implied blueprints components
#     are already in the system.
#     A blueprint does not 'imply' another specific blueprint,
#     but it 'implies' *some* blueprint bringing another specific component.
#
# Whether a brought blueprint is embedded or implied
# depends on the bringer value.
# For instance, it could be implied if user has not specified brought-blueprint data,
# and embedded if user has explicitly asked that it be.
#
# Implying blueprints for an abstract component is not currently supported,
# but could possibly be if it makes sense to do so.
#
# Blueprint may also require that other components be present
# for their expansion process to happen correctly,
# even though the component they bring does not.
# This blueprint requirement is specified by the 'expands_from' function.
# Expanding-from an abstract component A is expanding from any component subtyping A.

abstract type Blueprint{V} end
export Blueprint

# Every blueprint is supposed to bring exactly one major, concrete component.
# This method implements the mapping,
# and must be explicited by components devs.
struct UnspecifiedComponent{B<:Blueprint} end
componentof(::Type{B}) where {B<:Blueprint} = throw(UnspecifiedComponent{B}())
componentof(::B) where {B<:Blueprint} = componentof(B)

system_value_type(::Type{<:Blueprint{V}}) where {V} = V
system_value_type(::Blueprint{V}) where {V} = V

# Blueprints must be copyable, but be careful that the default (deepcopy)
# is not necessarily what component devs are after.
Base.copy(b::Blueprint) = deepcopy(b)

#-------------------------------------------------------------------------------------------
# Requirements.

# Return non-empty list if components are required
# for this blueprint to expand,
# even though the corresponding component itself would make sense without these.
expands_from(::Blueprint{V}) where {V} = CompsReasons{V}()
# The above is specialized by hand by framework users,
# so make its return type flexible,
# guarded by the below.
function checked_expands_from(bp::Blueprint{V}) where {V}
    err(x) = "Invalid expansion requirement. \
              Expected either a component for $V or (component, reason::String), \
              got instead: $(repr(x)) ::$(typeof(x))."
    to_reqreason(x) = if x isa Component{V}
            (typeof(x), nothing)
        elseif x isa CompType{V}
            (x, nothing)
        else
            req, reason = try
                q, r = x
                q, String(r)
            catch
                err()
            end
            if req isa Component{V}
                (typeof(x), reason)
            elseif x isa CompType{V}
                (x, reason)
            else
                err()
            end
        end
    x = expands_from(bp)
    try
        [to_reqreason(x)]
    catch
        Iterators.map(to_reqreason, x)
    end
end

# List brought blueprints.
# Yield blueprint values for embedded blueprints.
# Yield component types for implied blueprints (possibly abstract).
brought(b::Blueprint) = throw("Bringing from $(typeof(b)) is unimplemented.")
# Implied blueprints need to be constructed from the value on-demand,
# for a target component.
# No default method, so it can be checked
# whether it has been set from within @blueprint macro.
function implied_blueprint_for end # (blueprint, comptype) -> blueprint for this component.
function checked_implied_blueprint_for(b::Blueprint, C::CompType)
    bp = implied_blueprint_for(b, C)
    componentof(bp) <: C ||
        throw("Blueprint $(typeof(b)) is supposed to imply a blueprint for $C,
               but it implied a blueprint for $(componentof(bp)) instead:\n
               $b\n --- implied --->\n$bp")
    bp
end

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

# ==========================================================================================
# Explicit terminal display.
function Base.show(io::IO, ::MIME"text/plain", B::Type{<:Blueprint})
    print(
        io,
        "$B \
         $(crayon"black")\
         (blueprint type for component '$(componentof(B))')\
         $(crayon"reset")",
    )
end

function Base.showerror(io::IO, ::UnspecifiedComponent{B}) where {B}
    print(io, "Unspecified component for '$(repr(B))'.")
end
