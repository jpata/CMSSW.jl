import Base.convert, Base.getindex, Base.length, Base.pmap, Base.string

typealias TFile Ptr{Void}
typealias TBranch Ptr{Void}
typealias TTree Ptr{Void}
typealias VChar Ptr{Uint8}

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
function getindex(b::Branch, n::Integer)
    assert(b != C_NULL, "TBranch was NULL")
    r = ccall(
        (:tbranch_get_entry, "libroot"),
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
end
function getindex(t::Tree, n::Integer)
    assert(t != C_NULL, "TTree was NULL")
    r = ccall(
        (:ttree_get_entry, "libroot"),
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
    #eval(ex)
    return ex
end

getindex(t::Tree, r::Range1{Int64}) = map(n -> t[n], r)

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
    
    return Tree(tfile, ttree, filename, treepath, active_branches, branches)
end

Tree(t::Tree) = Tree(join([t.filename, t.treepath], ":"))
string(t::Tree) = string(t.filename, ":", t.treepath, t.tree)

function tfile_open(fname::ASCIIString)
    tfile = ccall(
        (:tfile_open, "libroot"),
        TFile, (VChar, ), fname
    )
    return tfile
end

function tfile_get(tfile::TFile, objname::ASCIIString)
    assert(tfile!=C_NULL, "TFile was 0")
    out = ccall(
        (:tfile_get, "libroot"),
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
        (:ttree_get_branches, "libroot"),
        Ptr{CArray}, (TTree, ), ttree
    )
    #println(out)
    arr = unsafe_load(out)
    return arr
end

function ttree_set_branch_address(ttree::TTree, b::Branch)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_set_branch_address, "libroot"),
        Cint, (TTree, VChar, Ptr{Void}), ttree, b.name, b.obj
    )
    return out
end


function ttree_set_branch_status(ttree::TTree, b::ASCIIString, status::Bool)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_set_branch_status, "libroot"),
        Cint, (TTree, VChar, Bool), ttree, b, status
    )
    return out
end
ttree_set_branch_status(ttree::TTree, b::Branch, status::Bool) = ttree_set_branch_status(ttree, b.name, status)


function ttree_get_entries(ttree::TTree)
    assert(ttree!=C_NULL, "TTree was 0")
    out = ccall(
        (:ttree_get_entries, "libroot"),
        Clong, (TTree,), ttree,
    )
    return out
end

# const tree = Tree("TTJets_FullLept.root:trees/Events")
# construct_type(tree)
# eval(make_constructor(Event, tree))
# event = Event(tree)

# n_entries = length(tree)

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
    #println("Bin index: ", low, " low edge=", h.bin_edges[low])
end


immutable LoopState
    hmupt::Histogram
    hcos::Histogram
    hcos_w1::Histogram
end

function run_loop()
    function my_loop(n::Int64, tree::Tree, s::LoopState)
        ev = tree[n]
        return true
    end
    function my_loop2(n)
        cos_theta::Float32 = tree.branches["cos_theta"][n]
        mu_pt::Float32 = tree.branches["mu_pt"][n]
        return cos_theta+mu_pt^2
    end

    function my_loop3(
            n::Int64, event::Event,
            s::LoopState
        )

        if !(event.n_muons[n] == 1 && event.n_eles[n] == 0)
            return false
        end
        if !(event.n_jets[n] == 2 && event.n_tags[n] == 1)
            return false
        end
        if !(event.mt_mu[n] > 50)
            return false
        end
        if !(event.rms_lj[n] < 0.025)
            return false
        end
        mu_pt = event.mu_pt[n]
        for i=1:100
            fill(s.hmupt, mu_pt)
        end
        cos_theta = event.cos_theta[n]
        fill(s.hcos, cos_theta)
        fill(s.hcos_w1, cos_theta, event.pu_weight[n])
        return true
    end

    state1 = LoopState(Histogram(20, 0, 100), Histogram(20, -1, 1), Histogram(20, -1, 1))
    t = @elapsed ret = map(n -> my_loop3(n, event, state1), 1:n_entries)
    println("Processed ", n_entries/t, " events/sec")

    for (bn, b) in tree.branches
        enable_branch(tree, bn)
    end

    state2 = LoopState(Histogram(20, 0, 100), Histogram(20, -1, 1), Histogram(20, -1, 1))
    t = @elapsed ret = map(n -> my_loop(n, tree, state2), 1:n_entries)
    println("Processed ", n_entries/t, " events/sec")

    state3 = LoopState(Histogram(20, 0, 100), Histogram(20, -1, 1), Histogram(20, -1, 1))
    t = @elapsed ret = map(n -> my_loop3(n, event, state3), 1:n_entries)
    println("Processed ", n_entries/t, " events/sec")

    return ret, state1, state2, state3
end

function pmap_tree(f::Function, tree::Tree)
    #On every subprocess, load parent file
    pname = join([tree.filename, tree.treepath], ":")
    @everywhere local_tree = Tree($(pname))

    @everywhere println(string(local_tree))

    # #Naive loop over all the lines in random order
    # nlines = length(fi.filebuf)
    # ret = fetch(pmap(
    #     n -> (
    #         (f(read_n(local_fi, n)), myid())
    #     ), 1:nlines
    # ))
    # return ret
end

# pmap_tree(x->x, tree)

#ret = run_loop()