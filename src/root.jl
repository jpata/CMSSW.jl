import Base.convert, Base.length, Base.pmap, Base.string

typealias TFile Ptr{Void}
typealias TBranch Ptr{Void}
typealias TTree Ptr{Void}
typealias VChar Ptr{Uint8}

const libroot = "lib/libroot.dylib"

immutable TreeBranch
    name::VChar
    dtype::VChar
    pbranch::TBranch
end

immutable CArray
    start::Ptr{Ptr{Void}}
    size::Cint
    n_elems::Cint
end

type_table = {"Float_t"=>Float32, "Int_t"=>Int32}
type Branch
    name::String
    dtype::Type
    obj::Array
    tbranch::TBranch
    function Branch(tb::TreeBranch)
        dt = bytestring(tb.dtype)
        if !haskey(type_table, dt)
            t = Void
            println("No type defined for ", dt)
        else
            t = type_table[dt]
        end
        arr = Array(t, 1)
        arr[1] = -999
        return new(bytestring(tb.name), t::Type, arr, tb.pbranch)
    end
    function Branch()
        obj = Array(Void, 1)
        return new("None", Void, obj, convert(Ptr{Void}, 0))
    end
end
function Base.getindex(b::Branch, n::Integer)
    assert(b != C_NULL, "TBranch was NULL")
    r = ccall(
        (:tbranch_get_entry, libroot),
        Cint, (TBranch, Cint), b.tbranch, n
    )
    return b.obj[1]
end

type Tree
    file::TFile
    tree::TTree
    filename::String
    treepath::String
    active_branches::Vector{ASCIIString}
    branches::Dict{Any, Any}
    index::Int64
end

Base.getindex(t::Tree, s::Symbol, n::Integer) = t.branches[string(s)][n]
Base.getindex(t::Tree, s::Symbol) = t[s,t.index]

length(t::Tree) = convert(Int64, ttree_get_entries(t.tree))

set_branch_status(t::Tree, b::ASCIIString, s::Bool) = ttree_set_branch_status(t.tree, b, s)

get_branches(t::TTree) = convert(TreeBranch, ttree_get_branches(t))
get_branches(t::Tree) = get_branches(t.tree)

function Tree(path::ASCIIString)
    spl = split(path, ":")
    filename = join(spl[1:length(spl)-1], ":")
    treepath = spl[length(spl)]

    tfile = tfile_open(filename)
    ttree = tfile_get(tfile, treepath)
    active_branches = Array(ASCIIString, 0)
    branches = {
        x.name::ASCIIString => x::Branch for x in get_branches(ttree)
    }
    for (brname, b) in branches
        ttree_set_branch_address(ttree, b)
    end
    
    t = Tree(tfile, ttree, filename, treepath, active_branches, branches, 1)
    #finalizer(t, x->println("Finalizing ", string(x)))
    return t
end

string(t::Tree) = string(t.filename, ":", t.treepath)

function tfile_open(fname::ASCIIString)
    tfile = ccall(
        (:tfile_open, libroot),
        TFile, (VChar, ), fname
    )
    return tfile
end

function tfile_close(tfile::TFile)
    tfile = ccall(
        (:tfile_close, libroot),
        Void, (TFile, ), tfile
    )
    return tfile
end

function ttree_set_cache(tree::TTree, size, learn)
    tfile = ccall(
        (:ttree_set_cache, libroot),
        Void, (TTree, Cint, Cint), tree, size, learn
    )
    return tfile
end

function tfile_get(tfile::TFile, objname::ASCIIString)
    assert(tfile!=C_NULL, "TFile was 0")
    out = ccall(
        (:tfile_get, libroot),
        Ptr{Void}, (TFile, VChar), tfile, objname
    )
    return out
end

function enable_branch(t::Tree, b::Branch)
    if !contains(t.active_branches, b.name)
        push!(t.active_branches, b.name)
    end
    ttree_set_branch_status(t.tree, b, true)
    ttree_set_branch_address(t.tree, b)
end
enable_branch(t::Tree, s::ASCIIString) = enable_branch(t, t.branches[s])

function disable_branch(t::Tree, b::Branch)
    pop!(t.active_branches, b.name)
    ttree_set_branch_status(t.tree, b, false)
    ttree_set_branch_address(t.tree, b)
end

function convert(typ::Type, arr::CArray)
    p = pointer(TreeBranch, arr.start)
    struct_arr = pointer_to_array(p, (convert(Int64, arr.n_elems),))
    out = map(x->Branch(x), struct_arr)
    for s in struct_arr
        c_free(s.name)
        c_free(s.dtype)
    end

    return out
end

function ttree_get_branches(ttree::TTree)
    assert(ttree!=C_NULL, "TFile was 0")
    out = ccall(
        (:ttree_get_branches, libroot),
        Ptr{CArray}, (TTree, ), ttree
    )
    #println(out)
    arr = unsafe_load(out)
    return arr
end

function ttree_set_branch_address(ttree::TTree, b::Branch)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_set_branch_address, libroot),
        Cint, (TTree, VChar, Ptr{Void}), ttree, b.name, b.obj
    )
    return out
end


function ttree_set_branch_status(ttree::TTree, b::ASCIIString, status::Bool)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_set_branch_status, libroot),
        Cint, (TTree, VChar, Bool), ttree, b, status
    )
    return out
end
ttree_set_branch_status(ttree::TTree, b::Branch, status::Bool) = ttree_set_branch_status(ttree, b.name, status)


function ttree_get_entries(ttree::TTree)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_get_entries, libroot),
        Clong, (TTree,), ttree,
    )
    return out
end

immutable Histogram
    bin_entries::Vector{Int64}
    bin_contents::Vector{Float64}
    bin_edges::Vector{Float64}
end

function Histogram(n::Integer, low::Number, high::Number)
    bins = linspace(low, high, n+1)
    unshift!(bins, -inf(Float64))
    n_contents = size(bins,1)
    return Histogram(
        zeros(Int64, (n_contents, )),
        zeros(Float64, (n_contents, )),
        bins
    )
end

Histogram(h::Histogram) = Histogram(h.bin_entries, h.bin_contents, h.bin_edges)

function fill!(h::Histogram, v::Real, w::Real=1.0)
    idx = searchsorted(h.bin_edges, v)
    low = idx.start-1
    h.bin_entries[low] += 1
    h.bin_contents[low] += w
end
function +(h1::Histogram, h2::Histogram)
    @assert h1.bin_edges == h2.bin_edges
    h = Histogram(h1.bin_entries + h2.bin_entries, h1.bin_contents+h2.bin_contents, h1.bin_edges)
    return h
end

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)
chunks(csize, nmax) = [chunk(csize, i, nmax) for i=1:convert(Int64, ceil(nmax/csize))]

macro onworkers(workers, ex)
    quote
        @sync begin
            for w in $workers
                remotecall(w, ()->eval(Main,$(Expr(:quote,ex))))
            end
        end
    end
end

function process_parallel(func::Function, tree_ex::Symbol, workers::Vector{Integer}, args...)
    @onworkers workers local_tree = eval($tree_ex)
    ntree = @fetchfrom workers[1] length(local_tree)
    chunksize = int(ntree / length(workers))
    ranges = chunks(chunksize, ntree)

    nr = 1
    refs = RemoteRef[]
    for r in ranges
        nproc = workers[mod1(nr, length(workers))]
        println("submitting chunk $(r.start):$(r.len) on worker $nproc")
        @spawnat nproc let
            
        end

        rr = remotecall(
            nproc,
            _r -> map(n -> func(n, local_tree, args...), _r), r
        )
        push!(refs, rr)
        nr += 1
    end
    return (ntree, refs)
end
