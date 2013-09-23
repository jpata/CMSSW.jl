const libfwlite = joinpath(Pkg.dir(), "ROOT.jl", "src", "CMSSW", "lib", ENV["SCRAM_ARCH"], "libfwlevents_jl")
const libroot = joinpath(Pkg.dir(), "ROOT.jl", "lib", "libroot")

immutable CArray
    start::Ptr{Ptr{Void}}
    size::Cint
    n_elems::Cint
end

try
    dlopen(libfwlite)
catch e
    println("could not load $libfwlite: $e")
    path = joinpath(Pkg.dir(), "ROOT.jl", "src", "CMSSW")
    warn("did you do 'cmsenv' CMSSW in $path ?")
    rethrow(e)
end


immutable InputTag
    p::Ptr{Void}
    label::Symbol
    instance::Symbol
    process::Symbol
    InputTag(label::Symbol, instance::Symbol, process::Symbol) = new(
        ccall(
            (:new_inputtag, libfwlite),
            Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}, Ptr{Uint8}), string(label), string(instance), string(process)
        ), label, instance, process
    )
end

for symb in [:vfloat]
    eval(quote
        $(symbol(string("get_by_label_", symb)))(ev::Ptr{Void}, h::Ptr{Void}, t::InputTag) = ccall(
            ($(string("get_by_label_", symb)), libfwlite),
            Ptr{Void}, (Ptr{Void}, Ptr{Void}, Ptr{Void}), ev, h,
            t.p
        )

        $(symbol(string("new_handle_", symb)))() = ccall(
            ($(string("new_handle_", symb)), libfwlite),
            Ptr{Void}, ()
        )
    end)
end

get_by_label_vfloat1(ev::Ptr{Void}, h::Ptr{Void}, t::InputTag) = ccall(
    (:get_by_label_vfloat, libfwlite),
    Ptr{Void}, (Ptr{Void}, Ptr{Void}, Ptr{Void}), ev, h,
    t.p
)

function fwlite_initialize()
    out = ccall(
        (:initialize, libfwlite),
        Void, (),
    )
    return out
end

immutable Handle
    p::Ptr{Void}
    t::Type
end

const type_table = {
    :floats => Vector{Cfloat}
}

function Handle(t::Type)
    if t==Vector{Cfloat}
        hp = new_handle_vfloat()
        return Handle(hp, t)
    else
        error("Handle not defined for type $t")
    end
end

Handle(s::Symbol) = Handle(type_table[s])

immutable Source
    tag::InputTag
    handle::Handle
end


type Events
    fnames::Vector{String}
    ev::Ptr{Void}
    tags::Dict{(Symbol, Symbol, Symbol), (InputTag, Handle)}
    index::Int64

    function Events(fnames)
        ev = ccall(
        (:new_chain_event, libfwlite),
        Ptr{Void}, (Ptr{Ptr{Uint8}}, Cuint), convert(Vector{ASCIIString}, fnames), length(fnames)
        )
        events = new(
            fnames, ev,
            Dict{(Symbol, Symbol, Symbol), (InputTag, Handle)}(),
            0
        )

        for (dtype, label, instance, process) in get_branches(events)
            try
                #events.tags[(label, instance, process)] = (InputTag(label, instance, process), Handle(dtype))
            catch e
                #warn("tag $dtype, $label, $instance, $process not created: $e")
            end
        end
        return events
    end
end

Events(fname::ASCIIString) = Events([fname])

function get_branches(ev::Events)
    parr = ccall(
        (:get_branches, libfwlite),
        Ptr{CArray}, (Ptr{Void}, ), ev.ev
    )
    arr = unsafe_load(parr)
    jarr = deepcopy(
        pointer_to_array(convert(Ptr{Ptr{Uint8}}, arr.start), (convert(Int64, arr.n_elems),))
    )

    ret = Vector{Symbol}[]
    for s in map(bytestring, jarr)
        symbs = split(s, "_") |>  x -> map(y -> symbol(strip(y, ['.'])), x)
        push!(ret, symbs)
    end
    return ret
end

function where(ev::Events)
    return ccall(
        (:events_fileindex, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    ) + 1
end

function Base.length(ev::Events)
    return ccall(
        (:events_size, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    )
end

function to!(ev::Events, n::Integer)
    scanned = ccall(
            (:events_to, libfwlite),
            Bool, (Ptr{Void}, Clong), ev.ev, n-1
    )
    scanned || error("failed to scan to event $n")
    ev.index = n
end

function Base.getindex(ev::Events, label::Symbol, instance::Symbol, process::Symbol)
    tag, handle = ev.tags[(label, instance, process)]
    return ev[tag, handle]
end

function Base.getindex(ev::Events, tag::InputTag, handle::Handle)
    ret::Ptr{Void} = get_by_label_vfloat1(ev.ev, handle.p, tag)
    return to_jl(ret)
end

function Base.getindex(ev::Events, s::Source)
    return ev[s.tag, s.handle]
end

function to_jl(p::Ptr{Void})

    parr = ccall(
            (:convert_vector, libfwlite),
            Ptr{CArray}, (Ptr{Void}, ), p
    )
    arr = unsafe_load(parr)
    jarr = pointer_to_array(convert(Ptr{Cfloat}, arr.start), (convert(Int64, arr.n_elems),))
    parr!= C_NULL && c_free(parr)
    return jarr
end

immutable EventID
    run::Cuint
    lumi::Cuint
    event::Cuint
end

function where(ev::Events)
    r = ccall(
        (:get_event_id, libfwlite), EventID, (Ptr{Void},), ev.ev
    )
    return (convert(Int64, r.run), convert(Int64, r.lumi), convert(Int64, r.event))
end

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)
chunks(csize, nmax) = [chunk(csize, i, nmax) for i=1:convert(Int64, ceil(nmax/csize))]

macro onworkers(targets, ex)
    quote
        @sync begin
            for w in $targets
                #println("Executing on $w")
                #remotecall(w, ()->eval(Main,$(Expr(:quote,ex))))
                #remotecall(w, () -> @eval $(Expr(:quote,ex)))
                @spawnat w eval(Main, $(Expr(:quote,ex)))
            end
        end
    end
end

function process_parallel(func::Function, tree_ex::Symbol, targets::Vector{Int64}, args...)

    newsymb = :local_tree#gensym("local_tree")
    @eval @onworkers $targets const $newsymb = eval($tree_ex)
    ntree = @fetchfrom targets[1] length(eval(Main, newsymb))
    chunksize = int(ntree / length(targets))
    ranges = chunks(chunksize, ntree)

    nr = 1
    refs = RemoteRef[]
    for r in ranges
        nproc = targets[mod1(nr, length(targets))]
        println("submitting chunk $(r.start):$(r.start+r.len) to worker $nproc, tree name=$newsymb")
        rr = remotecall(
            nproc,
            _r -> map(n -> func(n, eval(Main, newsymb), args...), _r), r
        )
        push!(refs, rr)
        nr += 1
    end
    return (ntree, refs)
end

export fwlite_initialize
export InputTag, Handle, EventID, Source
export Events
export to!
export where
export @onworkers, process_parallel