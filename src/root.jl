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
function Base.getindex(t::Tree, n::Integer)
    assert(t != C_NULL, "TTree was NULL")
    r = ccall(
        (:ttree_get_entry, libroot),
        Cint, (TTree, Cint), t.tree, n
    )
    return map(x -> t.branches[x].obj[1], t.active_branches)
end

function construct_type(t::Tree)
    ex = :(
        immutable Event
            tree::Tree
        end
    )
    for (bn, b) in t.branches
        var = :($(symbol(string(bn)))::Branch)
        push!(ex.args[3].args, var)
    end
    eval(ex)
    return Event
end
function make_constructor(typ::Type, tree::Tree)
    ex = :(
        $(symbol(string(typ)))(t::Tree) = $(symbol(string(typ)))(t)
    )
    for (bn, b) in tree.branches
        push!(ex.args[2].args, :($b))
        #:(get($(symbol("t.branches")), $bn, Branch())))
    end
    #println(ex)
    eval(ex)
    return ex
end

#Gets the branch value corresponding to the current row of the Event
# event: an Event instance
# branch: a :symbol with the branch name
macro get(event, branch)
    :((getfield($event, $branch))[$event.tree.index])
end

Base.getindex(t::Tree, r::Range1{Int64}) = map(n -> t[n], r)

length(t::Tree) = convert(Int64, ttree_get_entries(t.tree))

set_branch_status(t::Tree, b::ASCIIString, s::Bool) = ttree_set_branch_status(t.tree, b, s)

get_branches(t::TTree) = convert(TreeBranch, ttree_get_branches(t))
get_branches(t::Tree) = get_branches(t.tree)

function Tree(path::ASCIIString)
    filename, treepath = split(path, ":")
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
    evtype = construct_type(t)
    make_constructor(evtype, t)
    return t
end

Tree(t::Tree) = Tree(join([t.filename, t.treepath], ":"))
string(t::Tree) = string(t.filename, ":", t.treepath, t.tree)

function tfile_open(fname::ASCIIString)
    tfile = ccall(
        (:tfile_open, libroot),
        TFile, (VChar, ), fname
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

type Histogram
    bin_entries::Vector{Int64}
    bin_contents::Vector{Float64}
    bin_edges::Vector{Float64}
    function Histogram(n::Integer, low::Number, high::Number)
        bins = linspace(low, high, n+1)
        unshift!(bins, -inf(Float64))
        n_contents = size(bins,1)
        return new(
            zeros(Int64, (n_contents, )),
            zeros(Float64, (n_contents, )),
            bins
        )
    end
end
function fill(h::Histogram, v::Number, w::Number=1.0)
    idx = searchsorted(h.bin_edges, v)
    low = idx.start-1
    h.bin_entries[low] += 1
    h.bin_contents[low] += w
end

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)
chunks(csize, nmax) = [chunk(csize, i, nmax) for i=1:convert(Int64, ceil(nmax/csize))]

macro parloop(chunksize, loopexpr)
    range = loopexpr.args[1].args[2]
    iterator = loopexpr.args[1].args[1]
    #println("Iteration symbol = ", iterator)
    ranges = chunks(chunksize, eval(range).len)
    #println(ranges, " ", length(ranges))
    lex = loopexpr.args[2]
    loopfnex = :(
        function loop($iterator)
            #println("Calling wrapped loop on ", $iterator)
            #sleep(2)
            return $lex
        end
    )
    @everywhere eval($loopfnex)
    println("Done compiling loop expression, mapping...")


    refs = RemoteRef[]
    nr = 1
    for r in ranges
        nproc = mod1(nr, nprocs())
        rr = remotecall(
            nproc,
            _r -> begin
                nlooped = 0
                for __r in _r
                    if loop(__r)
                        nlooped+=1
                    end
                end
                return nlooped
            end, r
        )
        push!(refs, rr)
        nr += 1
    end
    println("Parallel loop spawned with ", length(refs), " jobs")
    return refs
end