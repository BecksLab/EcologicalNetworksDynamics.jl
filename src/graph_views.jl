# Anticipate future refactoring of the internals with this 'view' pattern.
#
# Values stored within an array today
# may not always be available under this form.
# Yet, properties like model.my_favourite_biorates need to keep working like arrays,
# and also to protect against illegal writes.
# To this end, design a special "View" into internals data,
# under the form of newtypes implementing AbstractArray interface.
#
# Assume that the internals will always provide at least
# a cached array version of the data,
# and reference this cache directly from the view.
# Implementors then just need to define how the data
# is supposed to be accessed or updated.
#
# Subtypes needs to be "fat slices" with the following fields:
#
#   ._ref:
#     Direct reference to the encapsulated data (possibly within the cache).
#
#   ._graph:
#     Direct reference to the overall graph model.
#
#   ._template: (optional)
#     Referenced or owned boolean mask
#     useful to forbid sparse data writes where not meaningful.
#
#   ._index (for nodes) or (._row_index, ._col_index) (for edges): (optional)
#     Referenced or owned mapping to convert symbol labels to integers.
#
# A convenience macro is defined outside this module
# to avoid having to manually define these fields,
# to correctly wire index/label checking depending on their presence
# and to integrate the view with the component Framework @methods.

module GraphViews

import ..Internal
import ..join_elided

using SparseArrays

const Option{T} = Union{Nothing,T}

# ==========================================================================================
# Dedicated exception.

struct ViewError <: Exception
    type::Type # (View type)
    message::String
end
Base.showerror(io::IO, e::ViewError) = print(io, "View error ($(e.type)): $(e.message)")

# ==========================================================================================
# Base type hierarchy.
# Define the plumbery methods to make views work.
# No magic in here, so the ergonomics would be weak without helper macros.

# Accepted input for symbol labels.
Label = Union{Symbol,Char,AbstractString}
# Abstract over either index or labels.
Ref = Union{Int,Label}

# All views must behave like regular arrays.
abstract type AbstractGraphDataView{T,N} <: AbstractArray{T,N} end

# Either 1D (for nodes data) or 2D (for edges data).
const AbstractNodesView{T} = AbstractGraphDataView{T,1}
const AbstractEdgesView{T} = AbstractGraphDataView{T,2}

# Read-only or read/write versions (orthogonal to the above)
abstract type AbstractGraphDataReadOnlyView{T,N} <: AbstractGraphDataView{T,N} end
abstract type AbstractGraphDataReadWriteView{T,N} <: AbstractGraphDataView{T,N} end

# Cartesian product of the above two pairs.
# TODO: split again between sparse and dense, to get better display.
abstract type NodesView{T} <: AbstractGraphDataReadOnlyView{T,1} end
abstract type NodesWriteView{T} <: AbstractGraphDataReadWriteView{T,1} end
abstract type EdgesView{T} <: AbstractGraphDataReadOnlyView{T,2} end
abstract type EdgesWriteView{T} <: AbstractGraphDataReadWriteView{T,2} end
export NodesView
export NodesWriteView
export EdgesView
export EdgesWriteView

# ==========================================================================================
# Defer base implementation to the ._ref field.

Base.size(v::AbstractGraphDataView) = size(v._ref)
SparseArrays.findnz(m::AbstractGraphDataView) = findnz(m._ref)
Base.:(==)(a::AbstractGraphDataView, b::AbstractGraphDataView) = a._ref == b._ref

# ==========================================================================================
# Checked access.

# Always valid for reading with indices (or we break AbstractArray contract).
function Base.getindex(v::AbstractGraphDataView, index::Int...)
    check_index_dim(v, index...)
    check_dense_index(v, nothing, index) # Always do to harmonize error messages.
    getindex(v._ref, index...)
end

# Always checked for labelled access.
function Base.getindex(v::AbstractGraphDataView, labels::Label...)
    check_index_dim(v, labels...)
    index = to_checked_index(v, labels...)
    getindex(v._ref, index...)
end
Base.getindex(v::AbstractGraphDataView) = check_index_dim(v) # (trigger correct error)

# Only allow writes for writeable views.
Base.setindex!(v::AbstractGraphDataReadWriteView, rhs, refs::Ref...) =
    setindex!(v, rhs, refs)
Base.setindex!(v::AbstractGraphDataReadOnlyView, args...) =
    throw(ViewError(typeof(v), "This view into graph edges data is read-only."))

function setindex!(v::AbstractGraphDataReadWriteView, rhs, refs)
    check_index_dim(v, refs...)
    index = to_checked_index(v, refs...)
    rhs = write!(v._graph, typeof(v), rhs, index)
    Base.setindex!(v._ref, rhs, index...)
end
inline(index, ::Tuple{Vararg{Int}}) = "$index"
inline(index, input) = "$index ($input)"

function to_checked_index(v::AbstractGraphDataView, index::Int...)
    check_index(v, nothing, index)
    index
end

function to_checked_index(v::AbstractGraphDataView, labels::Label...)
    index = to_index(v, labels...)
    check_index(v, labels, index)
    index
end

# Extension points for implementors.
check_index(v::AbstractGraphDataView, _...) = throw("Unimplemented for $(typeof(v)).")
check_label(v::AbstractGraphDataView, _...) = throw("Unimplemented for $(typeof(v)).")

# Check the value to be written prior to underlying call to `Base.setindex!`,
# and take this opportunity to possibly update other values within model besides ._ref.
# Returns the actual value to be passed to `setindex!`.
write!(::Internal, T::Type{<:NodesWriteView}, rhs, index) = rhs

# Name of the thing indexed, useful to improve errors.
item_name(::Type{<:AbstractGraphDataView}) = "item"
item_name(v::AbstractGraphDataView) = item_name(typeof(v))

level_name(::Type{<:AbstractNodesView}) = "node"
level_name(::Type{<:AbstractEdgesView}) = "edge"
level_name(v::AbstractGraphDataView) = level_name(typeof(v))

# ==========================================================================================
# All possible variants of additional index checking in implementors.

#-------------------------------------------------------------------------------------------
# Basic bound checks for dense views.

function check_dense_index(v::AbstractGraphDataView, ::Any, index::Tuple{Vararg{Int}})
    all(0 .< index .<= length(v)) && return
    item = uppercasefirst(item_name(v))
    level = level_name(v)
    s = plural(length(v))
    throw(ViewError(
        typeof(v),
        "$item index $(inline(index)) is off-bounds \
        for a view into $(inline(size(v))) $(level)$s data.",
    ))
end
inline(i) = "$i"
inline((i,)::Tuple{Int}) = "$i"
plural(n) = n > 1 ? "s" : ""

#-------------------------------------------------------------------------------------------
# For sparse views (a template is available as `._template`).

# Nodes.
function check_sparse_index(
    v::AbstractGraphDataView,
    labels::Option{Tuple{Vararg{Label}}}, # Remember if given as labels.
    index::Tuple{Vararg{Int}},
)
    check_dense_index(v, labels, index)
    :_template in fieldnames(typeof(v)) || return # Always valid without a template.

    template = v._template
    template[index...] && return
    item = item_name(v)
    level = level_name(v)
    n = length(index)
    valids = valid_refs(v, template, labels)
    refs, vrefs = if isnothing(labels)
        ("index $index", "indices")
    else
        ("label$(n > 1 : "s" : "") $labels ($index)", "labels")
    end
    throw(
        ViewError(
            typeof(v),
            "Invalid $item $refs to write $level data. Valid $vrefs $valids",
        ),
    )
end
valid_refs(_, template::Vector, ::Nothing) =
    "are " * join_elided(findnz(template)[1], ", ", " and "; max = 100)
valid_refs(_, template::Matrix, ::Nothing) =
    "are " *
    join_elided((ij for ij in zip(findnz(template)[1:2]...)), ", ", " and "; max = 50)
function valid_refs(v, template::Vector, ::Any)
    valids = valid_refs(v, template, nothing)
    "are " * join_elided((l for (l, i) in v._index if i in valids), ", ", " and "; max = 10)
end
valid_refs(_, template::Matrix, ::Any) =
    " must comply to the following template:\n$(repr(MIME("text/plain"), template))"


#-------------------------------------------------------------------------------------------
# Convert labels to indexes (a mapping is available as `._index`).

function to_index(v::AbstractNodesView, s::Label)
    map = v._index
    y = Symbol(s)
    if !haskey(map, y)
        item = item_name(v)
        throw(ViewError(
            typeof(v),
            "Invalid $item node label. \
             Expected $(either(keys(map))), \
             got instead: $(repr(s)).",
        ))
    end
    i = map[y]
    (i,)
end

function to_index(v::AbstractEdgesView, s::Label, t::Label)
    verr(mess) = throw(ViewError(typeof(v), mess))
    rows, cols = (v._row_index, v._col_index)
    y = Symbol(s)
    z = Symbol(t)
    if !haskey(rows, y)
        rows = sort(collect(keys(rows)))
        item = item_name(v)
        verr("Invalid $item edge source label: $(repr(y)). \
              Expected $(either(rows)), got instead: $(repr(s)).")
    end
    if !haskey(cols, z)
        cols = sort(collect(keys(cols)))
        verr("Invalid $item edge target label: $(repr(z)). \
              Expected $(either(cols)), got instead: $(repr(t)).")
    end
    i = rows[y]
    j = cols[z]
    (i, j)
end

either(symbols) =
    length(symbols) == 1 ? "$(repr(first(symbols)))" :
    "either " * join_elided(symbols, ", ", " or ")

# Accessing with the wrong number of dimensions.
function dimerr(reftype, v, level, exp, labs)
    n = length(labs)
    throw(
        ViewError(
            typeof(v),
            "$level data are $exp-dimensional: \
             cannot access $(item_name(v)) data values with $n $(reftype(n)): $labs.",
        ),
    )
end
laberr(args...) = dimerr(n -> n > 1 ? "labels" : "label", args...)
inderr(args...) = dimerr(n -> n > 1 ? "indices" : "index", args...)
check_index_dim(v::AbstractNodesView) = inderr(v, "Nodes", 1, ())
check_index_dim(v::AbstractEdgesView) = inderr(v, "Edges", 2, ())
check_index_dim(::AbstractNodesView, _::Int) = nothing
check_index_dim(::AbstractEdgesView, _::Int, _::Int) = nothing
check_index_dim(::AbstractNodesView, _::Label) = nothing
check_index_dim(::AbstractEdgesView, _::Label, _::Label) = nothing
check_index_dim(v::AbstractNodesView, labels::Label...) = laberr(v, "Nodes", 1, labels)
check_index_dim(v::AbstractEdgesView, labels::Label...) = laberr(v, "Edges", 2, labels)
# Requesting vector[1, 1, 1, 1] is actuall valid in julia.
# Only trigger the error out of this very strict 1-situation.
check_index_dim(v::AbstractNodesView, i::Int, index::Int...) =
    all(==(1), index) || inderr(v, "Nodes", 1, (i, index...))
check_index_dim(v::AbstractEdgesView, i::Int, j::Int, index::Int...) =
    all(==(1), index) || inderr(v, "Edges", 2, (i, j, index...))

# Accessing non-indexed views with labels.
no_labels(v::AbstractNodesView, s::Label) = throw(
    ViewError(typeof(v), "No index to interpret $(item_name(v)) node label $(repr(s))."),
)
no_labels(v::AbstractEdgesView, s::Label, t::Label) = throw(
    ViewError(
        typeof(v),
        "No index to interpret $(item_name(v)) edge labels $(repr.((s, t))).",
    ),
)

end
