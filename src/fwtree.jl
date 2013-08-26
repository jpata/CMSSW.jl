#fwtree.jl

using PyCall

function hello()
    ccall( (:hello, "libFWTree"), Void, ())
end

function init()
    ccall(
        (:initialize, "libFWTree"),
        Void, ()
    )
end

function make_vfloat()
    pt = ccall(
        (:make_handle_vfloat, "libFWTree"),
        Ptr{Void}, (),
    )
    return pt
end

dtype_handles = [
    Vector{Float32}=>make_vfloat
]

function load_file(fname::String)
    tfile = ccall(
        (:make_tfile, "libFWTree"),
        Ptr{Void}, (Ptr{Uint8}, ), fname
    )
    return tfile
end

function init_events(tfile::Ptr{Void})
    event = ccall(
        (:make_event, "libFWTree"),
        Ptr{Void}, (Ptr{Void}, ), tfile
    )
    return event
end

function event_toBegin(event::Ptr{Void})
    ccall(
            (:event_toBegin, "libFWTree"),
            Void, (Ptr{Void}, ), event
    )
end

function event_atEnd(event::Ptr{Void})
    return ccall(
            (:event_atEnd, "libFWTree"),
            Bool, (Ptr{Void}, ), event
    )
end

function event_next(event::Ptr{Void})
    return ccall(
            (:event_next, "libFWTree"),
            Ptr{Void}, (Ptr{Void}, ), event
    )
end

function event_getByLabel(_event::Ptr{Void}, label::String, handle::Ptr{Void})
    n = Array(Uint, 1)
    n[1] = 0
    out = ccall(
            (:event_getByLabel, "libFWTree"),
            Ptr{Cfloat}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Ptr{Uint}), _event, label, handle, n
    )
    _n::Int = n[1]
    if out != C_NULL
        arr = pointer_to_array(out, (_n,))
        return arr
    end
    return []
end

function del_obj(obj::Ptr{Void})
    ccall(
            (:del_obj, "libFWTree"),
            Void, (Ptr{Void}, ), obj
    )
end

type Branch
    _type::Type
    _module::String
    _name::String

    handle::Ptr{Void}
    label::String

    function Branch(a,b,c)
        x = new(a,b,c)
        x.handle = dtype_handles[x._type]()
        x.label = get_label(x)
        #println("Called constructor")
        return x
    end
end
get_label(b::Branch) = join([b._module, b._name], ":")
function get(event::Ptr{Void}, b::Branch)
    return event_getByLabel(event, b.label, b.handle)
end

branch_dtype = [
    "int"=>Int32, "float"=>Float32, "double"=>Float64,
    "floats"=>Vector{Float32}, "doubles"=>Vector{Float64}
]

function get_branches(tfile::Ptr{Void}, tree_name::String)
    _n_branches::Vector{Uint} = [1]
    out = ccall(
            (:get_branches, "libFWTree"),
            Ptr{Ptr{Uint8}}, (Ptr{Void}, Ptr{Uint8}, Ptr{Uint}), tfile, tree_name, _n_branches
    )
    n_branches = convert(Int, _n_branches[1])
    brpts = pointer_to_array(out, (n_branches,))
    brnames = map(x -> bytestring(x), brpts)
    map(x -> c_free(x), brpts)
    c_free(out)
    branches = Branch[]
    for brn in brnames
        spl = split(brn, "_")
        if size(spl)!=(4,)
            continue
        end
        dtype = spl[1]
        if !haskey(branch_dtype, dtype) || !haskey(dtype_handles, branch_dtype[dtype])
            continue
        end
        br = Branch(branch_dtype[dtype], spl[2], spl[3])
        push!(branches, br)
    end
    return branches
end

function do_loop(branches::Vector{Branch})
    #items = map(br -> br._type[], branches)
    i::Integer = 1

    tfile = load_file("test.root")
    event = init_events(tfile)

    println("Looping")
    event_toBegin(event)

    while !event_atEnd(event)
        prods = map(br -> get(event, br), branches)
        for p in prods
            println(p)
            fill(t, p)
        end
        #for (p, it) in zip(prods, items)
        #    push!(it, p)
        #end
        event = event_next(event)
        i = i + 1
    end
    println("Processed ", i, " events.")
    return 0
end

hello()
init()
#tfile = load_file("test.root")
#event = init_events(tfile)
#el = @elapsed pt=do_loop("goodJetsNTupleProducer:Pt")

tfile = load_file("test.root")
brs = get_branches(tfile, "Events")
#pt=do_loop(brs[100])

function load_root()
    try
        @pyimport libPyROOT as root
    catch y
        println(y)
        @pyimport libPyROOT as root
        return root
    end
end

root = load_root()

_TH1F = root.LookupRootEntity("TH1F")
type TH1F
    ref::PyObject
    function TH1F(args...)
        x = new(_TH1F(args...))
    end
end
fill(obj, x, w) = pycall(obj.ref[:Fill], Int, x, w)
fill(obj, x) = fill(obj, x, 1)


t = TH1F("myhist", "myhist", 20, -1, 1)
function test_fill(x::Integer = 100000)
    el = @elapsed for i=1:x
        fill(t, 0.1)
    end
    return el, x
end
#TH1F = root.LookupRootEntity("TH1F")
#t = TH1F("myhist", "myhist", 20, -1, 1)