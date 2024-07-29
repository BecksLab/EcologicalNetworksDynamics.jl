# This framework is dedicated to wrap a sophisticated value into a 'System'.
#
# Motivation:
#
#   The wrapped value is powerful but complicated
#   and its state needs to be carefully maintained.
#   Lib devs want to expose it to their users so they can enjoy the benefit of it,
#   but they also want to protect them from breaking the internal state.
#
# Instead of exposing the value directly,
# lib devs wrap it into a 'System':
#
#   s = System{WrappedValue}()
#
# And then they carefully develop an associated collection of 'components' and 'methods'.
#
# The whole module can be viewed as an extension of the "builder" pattern.
# Instead of constructing the value directly,
# lib users will start from an "empty" or "default" base system,
# then populate it with the 'components' at hand
# until it contains all the data required to exhibit the behaviour they need
# via the 'methods' at hand.
#
# Consistently with this "builder" approach,
# 'components' are not actual values,
# but rather abstract, diffuse sets of data appended to the protected state.
# In consequence, lib users cannot get a 'component' variable
# referring to data inside the system.
# Instead, they get 'blueprints' for components,
# which they can construct and tweak like regular julia structs.
# When ready, a blueprint can be read by the system, 'check'ed,
# and 'expand'ed into the actual component(s).
#
# No component can be added twice,
# but blueprints can be read and expanded into different components types.
# Also, the components they 'provide' may depend on their value
# and/or the current state of the system.
#
# 'Components' contain no data and are implemented as julia singletons marker types.
# 'Blueprints' are regular data structures implementing the blueprint interface.
#
# Adding a component to the system therefore reduces to:
#
#   add!(s, blueprint)
#
# And using exposed methods as simple:
#
#   method(s)
#
# Additional sugar is provided:
#
#   s = System{WrappedValue}(blueprints...) # Start from a sequence of initial blueprints.
#   s += blueprint                          # Provide new component from extra blueprint.
#   s.property                              # Implicit `get_property(s)`
#   s.property = value                      # Implicit `set_property(s, value)`
#
# Components and methods are organized into a dependency hierarchy,
# with components requiring each other
# and methods depending on the presence of certain components to run.
# This makes it possible to emit useful errors
# when lib users attempt to invoke the above behaviour
# but not all required components have been added to the system.
#
# Before being expanded into the components they provide,
# every blueprint is carefully checked by lib devs
# so they can guarantee that the internal state cannot be corrupted during expansion,
# and by the exposed System/Blueprints/Components/Methods interface in general.
#
# As a current limitation, there is no way to "remove" a component from the system,
# so the system evolution is monotonic.
# However, if the underlying wrapped value can be safely copied,
# then it is always possible to "fork" the system:
#
#   s = System{CopyableWrappedValue}(a::A, b::B, c::C)
#   fork = copy(s)
#   add!(fork, d::D)
#   has_component(fork, D) # True.
#   has_component(s, D) # False.
#
# This *may* make it useless to ever feature component removal.
module Framework

# TODO: Improve ergonomics:
#   - [x] Flesh early documentation.
#   - [x] Encourage moving sophisticated function definitions outside macro calls
#     to ease burden on `Revise`.
#   - [x] blueprints *optionnaly* bring other blueprints.
#   - [!] Components are not blueprint types, but an autonomous hierachy of singleton types.
#   - [.] "*blueprints* imply/bring *blueprints*", not "components imply/bring components"
#   - [.] Blueprints 'history' become meaningless if methods can mutate the internal state.
#   - [.] Recurring pattern: various blueprints types provide 'the same component': reify.
#   - [ ] `depends(other_method_name)` to inherit all dependent components.
#   - [ ] Namespace properties into like system.namespace.namespace.property.
#   - [ ] Hooks need to trigger when special components combination become available.
#         See for instance the expansion of `Nutrients.Nodes`
#         which should trigger the creation of links if there is already `Species`.. or vice
#         versa.

## HERE: Refactoring design.
## Components are identified by nodes in a type hierarchy,
## and exposed as singleton instances of concrete types in this hierarchy.
## A component may not be a plain marker types,
## and its fields may contain blueprint types for various blueprint providing it.
##
##    abstract type Component end
##
##    struct _Omega <: Component
##       Raw::Type{Blueprint}
##       Random::Type{Blueprint}
##       Allometry::Type{Blueprint}
##       Temperature::Type{Blueprint}
##    end
##
##    module OmegaBlueprints
##       # /!\ many redundant imports to factorize here.
##       struct Raw <: Blueprint ... end
##       struct Random <: Blueprint ... end
##       ...
##    end
##
##    const Omega = _Omega(
##       OmegaBlueprints.Raw,
##       OmegaBlueprints.Random,
##       ...
##    )
##    export Omega
##
##    function (C::_Omega)(args...; kwargs...)
##       if ..
##           C.Raw(...)
##       elseif ...
##           C.Random(...)
##       else ...
##       end
##    end
##
##    # Use as a blueprint constructor, but also as a blueprint namespace.
##    Omega(...)
##    Omega.Random(...)
##    Omega.Raw(...)
##
## Components require each other or conflict with each other.
## Blueprints bring each other.
## Blueprints are trees of sub-blueprints and must be treated as such.

using Crayons
using MacroTools
using OrderedCollections

argerr(m) = throw(ArgumentError(m))
const Option{T} = Union{T,Nothing}
struct PhantomData{T} end

# Abstract over various exception thrown during inconsistent use of the system.
abstract type SystemException <: Exception end

# Base structure.
include("./component.jl")
include("./blueprints.jl")
include("./methods.jl")
include("./system.jl")
include("./add.jl")
include("./plus_operator.jl")

# Exposed macros.
include("./macro_helpers.jl")
include("./component_macro.jl")
include("./blueprint_macro.jl")
include("./conflicts_macro.jl")
include("./method_macro.jl")

end
