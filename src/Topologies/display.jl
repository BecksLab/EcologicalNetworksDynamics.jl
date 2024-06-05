s(n) = n > 1 ? "s" : ""
are(n) = n > 1 ? "are" : "is"
function _th(n)
    b, i = n ÷ 10, n % 10
    b == 1 && return "th"
    i == 1 && return "st"
    i == 2 && return "nd"
    i == 3 && return "rd"
    "th"
end
th(n) = "$n$(_th(n))"

function Base.show(io::IO, top::Topology)
    n_nt = n_node_types(top)
    n_et = n_edge_types(top)
    n_n = sum((U.n_nodes(top, i) for i in 1:n_nt); init = 0)
    n_e = sum((U.n_edges(top, i) for i in 1:n_et); init = 0)
    print(
        io,
        "Topology(\
         $n_nt node type$(s(n_nt)), \
         $n_et edge type$(s(n_et)), \
         $n_n node$(s(n_n)), \
         $n_e edge$(s(n_e))\
         )",
    )
end

function Base.show(io::IO, ::MIME"text/plain", top::Topology)
    n_nt = n_node_types(top)
    n_et = n_edge_types(top)
    n_n = sum((U.n_nodes(top, i) for i in 1:n_nt); init = 0)
    n_e = sum((U.n_edges(top, i) for i in 1:n_et); init = 0)
    print(
        io,
        "Topology for $n_nt node type$(s(n_nt)) \
         and $n_et edge type$(s(n_et)) \
         with $n_n node$(s(n_n)) and $n_e edge$(s(n_e))",
    )
    if n_n > 0
        print(io, ":")
    else
        print(".")
    end
    println(io, "\n  Nodes:")
    for (i_type, type) in enumerate(_node_types(top))
        i_type > 1 && println(io)
        tomb = Symbol[] # Collect removed nodes to display at the end.
        print(io, "    $(repr(type)) => [")
        empty = true
        for i_node in U.nodes_abs_indices(top, i_type)
            node = U.node_label(top, i_node)
            if U.is_removed(top, i_node)
                push!(tomb, node)
                continue
            end
            empty || print(io, ", ")
            print(io, repr(node))
            empty = false
        end
        print(io, "]")
        if !isempty(tomb)
            print(io, "  <removed: $tomb>")
        end
    end
    n_e > 0 && print(io, "\n  Edges:")
    for (i_type, type) in enumerate(_edge_types(top))
        print(io, "\n    $(repr(type))")
        empty = true
        for (i_source, _neighbours) in U._outgoing_edges_indices(top, i_type)
            isempty(_neighbours) && continue
            source = U.node_label(top, Abs(i_source))
            print(io, "\n      $(repr(source)) => [")
            first = true
            for i_target in _neighbours
                target = U.node_label(top, Abs(i_target))
                first || print(io, ", ")
                print(io, repr(target))
                first = false
            end
            print(io, ']')
            empty = false
        end
        if empty
            print(io, " <none>")
        end
    end
end

# A debug display to just screen through the whole value.
debug(top::Topology) =
    for fn in fieldnames(Topology)
        val = getfield(top, fn)
        if fn in (:incoming, :outgoing)
            println("$fn: ")
            for (i_adj, adj) in enumerate(val)
                print("  $i_adj: ")
                if adj isa Tombstone
                    println("<tombstone>")
                    continue
                end
                for (i_et, et) in enumerate(adj)
                    print("\n    $i_et: $([i for i in et])")
                end
                println()
            end
        else
            println("$fn: $val")
        end
    end
