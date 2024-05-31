module TestTopologies

using EcologicalNetworksDynamics.Topologies
using Test

# Having correct 'show'/display implies that numerous internals are working correctly.
function check_display(top, short, long)
    @test "$top" == short
    io = IOBuffer()
    show(IOContext(io, :limit => true, :displaysize => (20, 40)), "text/plain", top)
    @test String(take!(io)) == long
end

top = Topology()
add_nodes!(top, Symbol.(collect("abcd")), :species)
add_nodes!(top, Symbol.(collect("uv")), :nutrients)
add_edge_type!(top, :trophic)
add_edge_type!(top, :mutualism)
add_edge_type!(top, :interference)
add_edge!(top, :trophic, :a, :b)
add_edge!(top, :trophic, :c, :b)
add_edge!(top, :trophic, :b, :d)
add_edge!(top, :trophic, :d, :u)
add_edge!(top, :trophic, :b, :v)
add_edge!(top, :mutualism, :a, :d)
add_edge!(top, :interference, :a, :c)

#! format: off
check_display(top,
   "Topology(2 node types, 3 edge types, 6 nodes, 7 edges)",
raw"Topology for 2 node types and 3 edge types with 6 nodes and 7 edges:
  Nodes:
    :species => [:a, :b, :c, :d]
    :nutrients => [:u, :v]
  Edges:
    :trophic
      :a => [:b]
      :b => [:d, :v]
      :c => [:b]
      :d => [:u]
    :mutualism
      :a => [:d]
    :interference
      :a => [:c]",
)
#! format: on

u = deepcopy(top)
remove_node!(u, :b)

#! format: off
check_display(u,
   "Topology(2 node types, 3 edge types, 5 nodes, 3 edges)",
raw"Topology for 2 node types and 3 edge types with 5 nodes and 3 edges:
  Nodes:
    :species => [:a, :c, :d]  <removed: [:b]>
    :nutrients => [:u, :v]
  Edges:
    :trophic
      :d => [:u]
    :mutualism
      :a => [:d]
    :interference
      :a => [:c]",
)
#! format: on

# Optionally provide node type so it's not searched.
v = deepcopy(top)
remove_node!(v, :b, :species)
@test u == v

# Input guards.
@argfails(
    add_nodes!(top, :a, :newtype),
    "The labels provided cannot be iterated into a collection of symbols. Received: :a."
)
@argfails(
    add_nodes!(top, [:a], :newtype),
    "Label :a was already given to a node of type :species."
)
@argfails(
    add_nodes!(top, [:x], :species),
    "Node type :species already exists in the topology."
)
@argfails(
    add_nodes!(top, [:x], :mutualism),
    "Node type :mutualism would be confused with edge type :mutualism."
)
@argfails(
    add_edge_type!(top, :mutualism),
    "Edge type :mutualism alerady exists in the topology."
)
@argfails(
    add_edge_type!(top, :species),
    "Edge type :species would be confused with node type :species."
)
@argfails(
    add_edge!(top, :x, :a, :b),
    "Invalid edge type label: :x. \
     Valid labels are :interference, :mutualism and :trophic."
)
@argfails(
    add_edge!(top, :trophic, :x, :b),
    "Invalid node label: :x. \
     Valid labels are :a, :b, :c, :d, :u and :v."
)
@argfails(add_edge!(u, :trophic, :a, :b), "Node :b has been removed from this topology.")
@argfails(
    add_edge!(top, :trophic, :a, :b),
    "There is already on edge of type :trophic between nodes :a and :b."
)
@argfails(
    remove_node!(u, :x),
    "Invalid node label: :x. \
     Valid labels are :a, :b, :c, :d, :u and :v.",
)
@argfails(
    remove_node!(u, :a, :x),
    "Invalid node type label: :x. \
     Valid labels are :nutrients and :species.",
)
@argfails(remove_node!(u, :b), "Node :b was already removed from this topology.")
@argfails(remove_node!(u, :b, :species), "Node :b was already removed from this topology.")
@argfails(remove_node!(top, :b, :nutrients), "Node :b is not of type :nutrients.")

end
