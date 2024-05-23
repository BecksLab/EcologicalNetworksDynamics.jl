module TestTopologies

using EcologicalNetworksDynamics.Topologies
using Test

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

# Having this correct display implies that numerous internals are working correctly.
@test "$top" == "Topology(2 node types, 3 edge types, 6 nodes, 7 edges)"
io = IOBuffer()
show(IOContext(io, :limit => true, :displaysize => (20, 40)), "text/plain", top)
@test String(take!(io)) ==
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
      :a => [:c]"


end
