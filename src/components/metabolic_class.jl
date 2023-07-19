# The metabolic class packs species within one of 3 classes:
#   - producer     (eat no other species in the model)
#   - invertebrate (one particular class of consumers)
#   - ectotherm    (one other particular class of consumers)
#
# These are either manually set (then checked against a foodweb for consistency)
# or automatically set in favour of invertebrate or consumers, based on a foodweb.
# In any case, a foodweb value must be present.

mutable struct MetabolicClass <: ModelBlueprint
    classes::@GraphData {Symbol, Vector}{Symbol}
    function MetabolicClass(classes)
        classes = @tographdata classes YV{Symbol}
        # Check that aliases are valid.
        classes isa Vector && AliasingDicts.standardize.(classes, MetabolicClassDict)
        # Redundant with later, proper check, but this doesn't hurt.
        @check_if_symbol classes (:all_invertebrates, :all_ectotherms)
        new(classes)
    end
end

function F.check(model, bp::MetabolicClass)
    (; classes) = bp

    @check_if_symbol classes (:all_invertebrates, :all_ectotherms)

    if classes isa Vector
        names = model.species_names
        prods = model.producers_mask
        for (cls, prod_sp, sp) in zip(bp.classes, prods, names)
            prod_class = AliasingDicts.is(cls, :producer, MetabolicClassDict)
            if prod_sp && !prod_class
                checkfails("Metabolic class for species $(repr(sp)) \
                            cannot be '$cls' since it is a producer.")
            elseif prod_class && !prod_sp
                checkfails("Metabolic class for species $(repr(sp)) \
                            cannot be '$cls' since it is a consumer.")
            end
        end
    end

end

function F.expand!(model, bp::MetabolicClass)
    (; classes) = bp

    # Get rid of aliases and standardize classes symbols.
    if classes isa Vector
        classes = AliasingDicts.standardize.(classes, MetabolicClassDict)
    end

    # Or Automatically set classes based on the foodweb.
    @expand_if_symbol(
        classes,
        :all_invertebrates =>
            [is_prod ? :producer : :invertebrate for is_prod in model.producers_mask],
        :all_ectotherms =>
            [is_prod ? :producer : :ectotherm for is_prod in model.producers_mask],
    )

    model._foodweb.metabolic_class = String.(classes) # Legacy conversion.
end

@component MetabolicClass requires(Foodweb)
export MetabolicClass

# ==========================================================================================
# Basic query.

@expose_data nodes begin
    property(metabolic_classes)
    get(MetabolicClasses{Symbol}, "species")
    ref_cache(m -> Symbol.(m._foodweb.metabolic_class)) # Legacy reverse conversion.
    @species_index
    depends(MetabolicClass)
end

# ==========================================================================================
# Display.

function F.display(model, ::Type{<:MetabolicClass})
    "Metabolic classes: [$(join_elided(model.metabolic_classes, ", "))]"
end
