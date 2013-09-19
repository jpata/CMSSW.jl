require("src/root.jl")

@everywhere begin
const libfwlite = "lib/libFWTree.dylib"

function fwlite_initialize()
    out = ccall(
        (:initialize, libfwlite),
        Void, (),
    )
    return out
end

fwlite_initialize()

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

type Events
    tfile::TFile
    ev::Ptr{Void}
    handles::Dict{InputTag, Ptr{Void}}
    tags::Dict{(Symbol, Symbol), InputTag}
    index::Int64

    function Events(s::ASCIIString)
        tfile = tfile_open(s)
        ev = ccall(
        (:events, libfwlite),
        Ptr{Void}, (TFile, ), tfile
        )
        return new(tfile, ev, Dict{InputTag, Ptr{Void}}(), Dict{(Symbol, Symbol), InputTag}(), 0)
    end
end

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

function Base.length(ev::Events)
    return ccall(
        (:events_size, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    )
end

function Base.getindex(ev::Events, n::Integer)
    scanned = ccall(
            (:events_to, libfwlite),
            Bool, (Ptr{Void}, Clong), ev.ev, n
    )
    scanned || error("failed to scan to event $n")
    ev.index = n
    return ev
end

function Base.getindex(ev::Events, s::InputTag)
    if !haskey(ev.handles, s)
        ev.handles[s] = ccall(
            (:new_handle_vfloat, libfwlite),
            Ptr{Void}, ()
        )
    end
    ret = ccall(
        (:get_by_label_vfloat, libfwlite),
        Ptr{Void}, (Ptr{Void}, Ptr{Void}, Ptr{Void}), ev.ev, ev.handles[s], s.p
    )
    return ret |> to_vector
end

function Base.getindex(ev::Events, label::Symbol, instance::Symbol)
    if !haskey(ev.tags, (label, instance))
        ev.tags[(label, instance)] = InputTag(label, instance, symbol(""))
    end
    return ev[ev.tags[(label, instance)]]
end

function to_vector(p::Ptr{Void})
    parr = ccall(
            (:convert_vector, libroot),
            Ptr{CArray}, (Ptr{Void}, ), p
    )
    arr = unsafe_load(parr)
    # jarr = deepcopy(
    #     pointer_to_array(convert(Ptr{Cfloat}, arr.start), (convert(Int64, arr.n_elems),))
    # )
    jarr = pointer_to_array(convert(Ptr{Cfloat}, arr.start), (convert(Int64, arr.n_elems),))
    parr!= C_NULL && c_free(parr)
    return jarr
end


    ev = Events("dat/test_edm.root")

    immutable Lepton
        pt::Float32
        eta::Float32
        phi::Float32
        iso::Float32
    end

    hist_pt = Histogram(10, 0, 200)

    function loop(n::Integer, events::Events)
        global hist_pt
        
        events[n]
        iso = events[:goodSignalMuonsNTupleProducer, :relIso]
        pt = events[:goodSignalMuonsNTupleProducer, :Pt]
        eta = events[:goodSignalMuonsNTupleProducer, :Eta]
        phi = events[:goodSignalMuonsNTupleProducer, :Phi]

        for m in zip(pt, eta, phi, iso)
            mu = Lepton(m...)
            #push!(leptons, mu)
            fill!(hist_pt, mu.pt)
        end
        return true
    end
end
println("Workers: $(join(workers(), ", "))")
rworkers = workers()
symb = :ev
@eval @onworkers $rworkers local_tree = eval($symb)

#println("Local: ", local_tree)
@onworkers rworkers println("onworker $(myid()): $local_tree")
nevents, refs = process_parallel(loop, :ev, rworkers)

println("Submitted, waiting...")
el = @elapsed for r in refs
    wait(r)
end
speed = nevents/el
println("Done: $speed events/sec")

for w in rworkers
    hist = @fetchfrom w eval(:hist_pt)
    println(hist)
end

