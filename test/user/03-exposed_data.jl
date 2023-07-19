# Cover @exposed_data macro results via existing components.
module TestExposedData

using EcologicalNetworksDynamics
using Test

Value = EcologicalNetworksDynamics.InnerParms # To make @sysfails work.
import ..Main: @viewfails, @sysfails, @argfails

const EN = EcologicalNetworksDynamics

# ==========================================================================================
@testset "Foodweb as a typical example of exposed data." begin

    SN = EN.SpeciesNames
    PM = EN.ProducersMask
    HL = EN.HerbivorousLinks

    m = Model(Foodweb([:a => [:b, :c], :b => :c]))

    #---------------------------------------------------------------------------------------
    # Nodes view.

    # Access with either indices or labels.
    @test m.producers_mask[1] == false
    @test m.producers_mask[:a] == false
    @test m.producers_mask['a'] == false
    @test m.producers_mask["a"] == false

    # Access ranges, masks, etc.
    @test m.producers_mask[2:3] == Bool[0, 1]
    @test m.producers_mask[Bool[1, 0, 1]] == Bool[0, 1]
    @test m.producers_mask[2:end] == Bool[0, 1]
    @test m.producers_mask[2:end-1] == Bool[0]

    # Invalid index.
    @viewfails(
        m.producers_mask[5],
        PM,
        "Species index '5' is off-bounds for a view into 3 nodes data."
    )

    # Invalid label.
    @viewfails(
        m.producers_mask['x'],
        PM,
        "Invalid species node label. \
         Expected either :a, :b or :c, got instead: 'x'."
    )

    # Label access into a view without an index.
    @viewfails(m.species_names[:a], SN, "No index to interpret species node label :a.")

    # Forbid mutation.
    @viewfails(
        m.producers_mask[1] = true,
        PM,
        "This view into graph nodes data is read-only."
    )
    @viewfails(
        m.producers_mask[1:2] = true,
        PM,
        "This view into graph nodes data is read-only."
    )

    @sysfails(
        m.producers_mask = Bool[1, 1, 1],
        Property(producers_mask),
        "This property is read-only."
    )

    # Same with edges.

    #---------------------------------------------------------------------------------------
    # Edges view.

    @test m.herbivorous_links[2, 3] == true
    @test m.herbivorous_links[:b, :c] == true
    @test m.herbivorous_links[1:2, 2:3] == [
        0 1
        0 1
    ]

    @viewfails(
        m.herbivorous_links[5, 8],
        HL,
        "Herbivorous link index (5, 8) is off-bounds \
         for a view into (3, 3) edges data."
    )

    @viewfails(
        m.herbivorous_links[:x, :b],
        HL,
        "Invalid herbivorous link edge source label: :x. \
         Expected either :a, :b or :c, got instead: :x."
    )

    @viewfails(
        m.herbivorous_links[:a, :x],
        HL,
        "Invalid herbivorous link edge target label: :x. \
         Expected either :a, :b or :c, got instead: :x."
    )

    # Can't mix styles.
    @argfails(m.herbivorous_links[:x, 8], "invalid index: :x of type Symbol")

    @viewfails(
        m.herbivorous_links[1, 2] = true,
        HL,
        "This view into graph edges data is read-only."
    )
    @viewfails(
        m.herbivorous_links[1:2, 2:3] = true,
        HL,
        "This view into graph edges data is read-only."
    )

    @sysfails(
        m.herbivorous_links = Bool[0 1; 0 1],
        Property(herbivorous_links),
        "This property is read-only."
    )

end

@testset "Hill exponent as a typical example of mutable exposed graph data." begin

    m = Model(HillExponent(5))

    # Read.
    @test m.hill_exponent == 5

    # Write.
    m.hill_exponent = 8
    @test m.hill_exponent == 8
    # Conversion happened.
    @test m.hill_exponent isa Float64

    # Type-guard.
    @sysfails(
        m.hill_exponent = "string",
        Property(hill_exponent),
        "Cannot set with a value of type String: \"string\"."
    )
    @sysfails(
        m.hill_exponent = [],
        Property(hill_exponent),
        "Cannot set with a value of type Vector{Any}: Any[]."
    )

end

@testset "Growth as a typical example of mutable exposed sparse node data." begin

    GR = EN.GrowthRates

    m = default_model(Foodweb([:a => [:b, :c], :b => [:c, :d]]))

    # Allow single-value write.
    @test m.r == [0, 0, 1, 1]
    m.r[3] = 2
    @test m.r == [0, 0, 2, 1]
    @test m.growth_rate == [0, 0, 2, 1] # (no matter the alias)

    m.r[:c] = 3
    @test m.r == m.growth_rate == [0, 0, 3, 1]

    # Allow range-writes, feeling like a regular array.
    m.r[3:4] .= 4
    @test m.r == m.growth_rate == [0, 0, 4, 4]
    m.r[3:4] = [5, 6]
    @test m.r == m.growth_rate == [0, 0, 5, 6]

    # Lock the lid of the following pandora box.
    @sysfails(m.r = [0, 0, 7, 8], Property(r), "This property is read-only.")
    # (allowing the above would easily lead to leaking references or invalidating views)

    # But here one correct way to replace the whole data in-place.
    m.r[m.producers_mask] = [9, 10]
    @test m.r == m.growth_rate == [0, 0, 9, 10]

    # So that aliasing views work as expected:
    view = m.r
    @test view == [0, 0, 9, 10]
    m.r[3:4] = [11, 12]
    @test view == [0, 0, 11, 12]

    # Disallow meaningless writes outside the template.
    @viewfails(
        m.r[2] = 1,
        GR,
        "Invalid producer index '2' to write data. Valid indices are:\n  [3, 4]"
    )
    @viewfails(
        m.r[:b] = 1,
        GR,
        "Invalid producer label 'b' to write data. Valid labels are:\n  [:c, :d]"
    )
    @viewfails(
        m.r[2:3] .= 1,
        GR,
        "Invalid producer index '2' to write data. Valid indices are:\n  [3, 4]"
    )

end

@testset "Mortality as a typical example of mutable exposed dense node data." begin

    m = default_model(Foodweb([:a => [:b, :c], :b => [:c, :d]]))

    @test m.d == [0, 0, 0, 0]

    # Lock the pandora lid.
    @sysfails(m.d = [1, 2, 3, 4], Property(d), "This property is read-only.")

    # But replacing the whole data inplace is possible.
    m.d .= [5, 6, 7, 8]
    @test m.d == [5, 6, 7, 8]

end

@testset "Efficiency as a typical example of mutable exposed edge data." begin

    EF = EN.EfficiencyRates
    m = default_model(
        Foodweb([:a => [:b, :c], :b => [:c, :d]]),
        Efficiency(:Miele2019; e_herbivorous = 1, e_carnivorous = 2),
    )

    @test m.efficiency == m.e == [
        0 2 1 0
        0 0 1 1
        0 0 0 0
        0 0 0 0
    ]

    # Allow single-value write.
    m.e[2, 3] = 3
    @test m.efficiency == m.e == [
        0 2 1 0
        0 0 3 1
        0 0 0 0
        0 0 0 0
    ]

    m.e[:b, :d] = 4
    @test m.e == [
        0 2 1 0
        0 0 3 4
        0 0 0 0
        0 0 0 0
    ]

    m.e[5] = 5
    @test m.e == [
        0 5 1 0
        0 0 3 4
        0 0 0 0
        0 0 0 0
    ]

    # Allow range-writes, feeling like a regular matrix.
    m.e[1:2, 3] .= 6
    @test m.e == [
        0 5 6 0
        0 0 6 4
        0 0 0 0
        0 0 0 0
    ]
    m.e[1:2, 3] = [8, 9]
    @test m.e == [
        0 5 8 0
        0 0 9 4
        0 0 0 0
        0 0 0 0
    ]

    # Lock the lid of the following pandora box.
    @sysfails(m.e = [0 0; 1 1], Property(e), "This property is read-only.")
    # (allowing the above would easily lead to leaking references or invalidating views)

    # But here one correct way to replace the whole data.
    m.e[m.A] = [1, 2, 3, 4]
    @test m.e == [
        0 1 2 0
        0 0 3 4
        0 0 0 0
        0 0 0 0
    ]

    # So that aliasing views work as expected:
    view = m.efficiency
    @test view == [
        0 1 2 0
        0 0 3 4
        0 0 0 0
        0 0 0 0
    ]
    m.e[1:2, 3] = [5, 6]
    @test view == [
        0 1 5 0
        0 0 6 4
        0 0 0 0
        0 0 0 0
    ]

    # Disallow meaningless writes outside the template.
    @viewfails(
        m.e[2] = 1,
        EF,
        "Invalid trophic link index (2, 1) to write data. Valid indices are:\n  \
         [(1, 2), (1, 3), (2, 3), (2, 4)]"
    )
    @viewfails(
        m.e[:b, :a] = 1,
        EF,
        "Invalid trophic link index (2, 1) (:b, :a) to write data. Valid indices are:\n  \
         [(1, 2), (1, 3), (2, 3), (2, 4)]"
    )
    @viewfails(
        m.e[2:3, 2:4] .= 1,
        EF,
        "Invalid trophic link index (2, 2) to write data. Valid indices are:\n  \
         [(1, 2), (1, 3), (2, 3), (2, 4)]"
    )

end

@testset "Nutrients concentration as non-squared edge data + dense template indexes." begin

    CN = EN.Nutrients.Concentrations
    m = Model(Foodweb([:a => [:b, :c]]), Nutrients.Nodes([:u, :v, :w]))
    m += Nutrients.Concentration([
        1 2 3
        4 5 6
    ])

    # Watch the semantics here: 2 is not the "2nd species", but the "2nd producer".
    c = m.nutrients_concentration
    c[2, 3] = 7
    @test m.nutrients_concentration == c == [
        1 2 3
        4 5 7
    ]

    # And :b is the "1st producer".
    c[:b, :v] = 8
    @test m.nutrients_concentration == c == [
        1 8 3
        4 5 7
    ]

    # Guard against meaningless accesses outside the references spaces.
    @viewfails(
        c[3, 1],
        CN,
        "Producer-to-nutrient link index (3, 1) is off-bounds \
         for a view into (2, 3) edges data."
    )
    @viewfails(
        c[:x, :u],
        CN,
        "Invalid producer-to-nutrient link edge source label: :x. \
         Expected either :b or :c, got instead: :x."
    )
    @viewfails(
        c[:b, :x],
        CN,
        "Invalid producer-to-nutrient link edge target label: :x. \
         Expected either :u, :v or :w, got instead: :x."
    )
end

end
