# Add components to the system: check and expand.

function add!(system::System{V}, blueprints::Blueprint{V}...) where {V}
    for bp in blueprints
        # Get our owned local copy so it cannot be changed afterwards.
        bp = copy(bp)
        _add!(system, bp)
    end
    system
end
export add!

#-------------------------------------------------------------------------------------------
# Internals: assume the blueprint we retrieve here is already owned by the system.

function _add!(system::System{V}, blueprint::Blueprint{V}) where {V}

    component = typeof(blueprint)

    # Collect base patches while checking their compatibility with current system state.
    try
        # Check compatibility with current system state.
        implied = implies(blueprint)
        brought = brings(blueprint)
        # (*) Quick patch 1-step deeper before this all gets refactored
        # with proper reification of blueprints tree structure.
        implied2 = OrderedDict()
        for B in reverse(brought) # First implied gets precedence.
            sub_bp = construct_brought(B, blueprint)
            for I in implies(sub_bp)
                implied2[I] = sub_bp
            end
        end

        # Cannot add components twice.
        has_component(system, component) && checkfails("cannot add components twice.")

        # Cannot add against conflicting components.
        for (abstract, would_conflict, reason) in conflicts(component)
            for conflict in components(system, would_conflict)
                reason = isnothing(reason) ? "." : ": $reason"
                as_a = component === abstract ? "" : " (as '$abstract')"
                as_w = conflict === would_conflict ? "" : " (as '$would_conflict')"
                checkfails("conflicts$(as_a) with component '$conflict'$(as_w)$(reason)")
            end
        end

        # Check that all required components are met.
        for (fn, needed) in
            [(requires, requires(component)), (buildsfrom, buildsfrom(blueprint))]
            for need in needed
                need, reason = need isa Pair ? need : (need, nothing)
                if !has_component(system, need)
                    # Missing, but this is okay if
                    # the component is about to be implied or brought.
                    any(I <: need for I in implied) && continue
                    any(B <: need for B in brought) && continue
                    # TODO: (*) the above check is not sufficient,
                    # as it should recursively check into every implied/brought blueprint's
                    # *own* implied/brought blueprints.
                    # This is rather non-trivial because blueprints need to be built
                    # before it can be determine which other sub-blueprints they bring.
                    # Better not tackle this before the framework gets refactored
                    # with a better distinction between 'blueprint' and 'component',
                    # and a unification of the 'implied' and 'brought' sub-blueprints.
                    # As a quick patch, dig at least one step further down into brought->implied.
                    any(I2 <: need for I2 in keys(implied2)) && continue
                    reason = isnothing(reason) ? "." : ": $reason"
                    a = isabstracttype(need) ? " a" : ""
                    if fn == requires
                        checkfails("missing$a required component '$need'$(reason)")
                    else
                        checkfails(
                            "blueprint cannot expand without$a component '$need'$(reason)",
                        )
                    end
                end
            end
        end

        # Pre-implied check hook.
        early_check(system._value, blueprint, system)

        # Automatically construct and add any missing implied/brought components.
        miss = OrderedDict() # Indexed by component type.

        # (*) Quick-patch 1-step deeper anticipation of blueprints implied
        # by brought blueprints.
        for (I2, sub_bp) in implied2
            if !has_component(system, I2)
                miss[componentof(I2)] = construct_implied(I2, sub_bp)
            end
        end
        for I in implied
            cI = componentof(I)
            if !has_component(system, I) && !haskey(miss, cI)
                # Failure here are not expected 'checkfails',
                # but framework usage failures.
                miss[cI] = construct_implied(I, blueprint)
            end
        end
        for B in brings(blueprint)
            if has_component(system, B)
                checkfails("blueprint also brings '$B', \
                            which is already in the system.")
            end
            cB = componentof(B)
            miss[cB] = construct_brought(B, blueprint)
        end

        # Recurse into adding all implied/brought components.
        for (_, m) in miss
            # TODO: this should *not* be a full addition, but only checking,
            # otherwise check failure in the next line
            # would result in the implied/brought components being added
            # but not this one.
            # Consequence: two components cannot be both implied/brought
            # if they need to be checked against each other,
            # unless the whole system be internally copied for checking on every addition.
            _add!(system, m)
        end

        # Verify actual value consistency.
        check(system._value, blueprint, system)

        # Record.
        bps, abs = system._blueprints, system._abstracts
        bps[component] = blueprint
        for sup in supertypes(component)
            sup === component && continue
            sup === Blueprint{V} && break
            sub = haskey(abs, sup) ? abs[sup] : (abs[sup] = Set{Component{V}}())
            push!(sub, component)
        end

    catch e
        if e isa BlueprintCheckFailure
            e.V = V
            push!(e.stack, blueprint)
        else
            @error "\n$(crayon"red")\
                    ⚠ Unexpected failure when expanding blueprint for '$component' \
                    to system for '$V'. ⚠\
                    $(crayon"reset")\n\
                    This is either a bug in the framework or in the components library. \
                    Consider reporting if you can reproduce with a minimal working example."
        end
        rethrow(e)
    end

    # Now that all guards have worked, alter the actual value.
    try
        expand!(system._value, blueprint, system)
    catch
        syserr(
            V,
            "\n$(crayon"red")\
             ⚠ ⚠ ⚠ Failure during expansion of component '$component' for '$V'. ⚠ ⚠ ⚠\
             $(crayon"reset")\n\
             This system state consistency is no longer guaranteed by the program. \
             This should not happen and must be considered a bug \
             within the components library. \
             Consider reporting if you can reproduce with a minimal working example. \
             In any case, please drop the current system value and create a new one.",
        )
    end

    system

end
