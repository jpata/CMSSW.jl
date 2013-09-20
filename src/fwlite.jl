module fwlite

include("bareroot.jl")

const libfwlite = joinpath(Pkg.dir(), "ROOT.jl", "lib", "libFWTree.dylib")

export fwlite_initialize
export InputTag
export Events

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
    fnames::Vector{String}
    ev::Ptr{Void}
    handles::Dict{InputTag, Ptr{Void}}
    tags::Dict{(Symbol, Symbol), InputTag}
    index::Int64

    function Events(fnames::Vector{String})
        ev = ccall(
        (:new_chain_event, libfwlite),
        Ptr{Void}, (Ptr{Ptr{Uint8}}, Cuint), fnames, length(fnames)
        )
        return new(fnames, ev, Dict{InputTag, Ptr{Void}}(), Dict{(Symbol, Symbol), InputTag}(), 0)
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
            Bool, (Ptr{Void}, Clong), ev.ev, n-1
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
    p != C_NULL || error("product not found")

    parr = ccall(
            (:convert_vector, libroot),
            Ptr{CArray}, (Ptr{Void}, ), p
    )
    arr = unsafe_load(parr)
    jarr = deepcopy(pointer_to_array(convert(Ptr{Cfloat}, arr.start), (convert(Int64, arr.n_elems),)))
    parr!= C_NULL && c_free(parr)
    return jarr
end

end #module


# ev = Events(
#     open(readall, "input.txt") |> split
# )

# immutable Lepton
#     pt::Float32
#     eta::Float32
#     phi::Float32
#     iso::Float32
# end

# hist_pt = Histogram(10, 0, 200)

# leptons = Lepton[]
# function loop(n::Integer, events::Events)
#     global hist_pt::Histogram
#     global leptons

#     curleptons = Lepton[]

#     events[n]
#     iso = events[:allMuonsNTP, :relIso]
#     pt = events[:allMuonsNTP, :Pt]
#     eta = events[:allMuonsNTP, :Eta]
#     phi = events[:allMuonsNTP, :Phi]

#     for m in zip(pt, eta, phi, iso)
#         mu = Lepton(m...)
#         #push!(curleptons, mu)
#         #fill!(hist_pt, mu.pt)
#         push!(leptons, mu)
#     end
#     #println("N=$(length(curleptons)), isos={",join([l.iso for l in curleptons], ","), "}")
#     return true
# end

# println("Workers: $(join(workers(), ", "))")
# rworkers = workers()
# symb = :ev
# @eval @onworkers $rworkers local_tree = eval($symb)

# println("number of events: ", length(ev))

# @onworkers rworkers println("onworker $(myid()): $local_tree")
# nevents, refs = process_parallel(loop, :ev, rworkers)

# println("Submitted, waiting...")
# el = @elapsed for r in refs
#     wait(r)
# end
# speed = nevents/el
# println("Done: $speed events/sec")

# for w in rworkers
#     #hist = @fetchfrom w eval(:hist_pt)
#     #println(hist)
#     leptons = @fetchfrom w eval(:leptons)
#     println(leptons)
# end
