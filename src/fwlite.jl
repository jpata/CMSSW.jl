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

for symb in [:vfloat]
    eval(quote
        $(symbol(string("get_by_label_", symb)))(ev::Ptr{Void}, h::Ptr{Void}, t::Ptr{Void}) = ccall(
            ($(string("get_by_label_", symb)), libfwlite),
            Ptr{Void}, (Ptr{Void}, Ptr{Void}, Ptr{Void}), ev, h, t
        )

        $(symbol(string("new_handle_", symb)))() = ccall(
            ($(string("new_handle_", symb)), libfwlite),
            Ptr{Void}, ()
        )
    end)
end

function fwlite_initialize()
    out = ccall(
        (:initialize, libfwlite),
        Void, (),
    )
    return out
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

type Events
    fnames::Vector{String}
    ev::Ptr{Void}
    tags::Dict{(Symbol, Symbol, Symbol), (InputTag, Handle)}
    index::Int64

    function Events(fnames::Vector{ASCIIString})
        ev = ccall(
        (:new_chain_event, libfwlite),
        Ptr{Void}, (Ptr{Ptr{Uint8}}, Cuint), fnames, length(fnames)
        )
        events = new(
            fnames, ev,
            Dict{(Symbol, Symbol, Symbol), (InputTag, Handle)}(),
            0
        )

        for (dtype, label, instance, process) in get_branches(events)
            try
                events.tags[(label, instance, process)] = (InputTag(label, instance, process), Handle(dtype))
            catch e
                warn("tag $dtype, $label, $instance, $process not created: $e")
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

    ret = C_NULL
    if handle.t == Vector{Cfloat}
        ret = get_by_label_vfloat(ev.ev, handle.p, tag.p)
    else
        error("get_by_label_ not defined for handle $handle")
    end

    ret != C_NULL || error("product $tag not found")

    return to_jl(ret, Cfloat)
end

function to_jl(p::Ptr{Void}, T::Type)

    parr = ccall(
            (:convert_vector, libroot),
            Ptr{CArray}, (Ptr{Void}, ), p
    )
    arr = unsafe_load(parr)
    jarr = deepcopy(pointer_to_array(convert(Ptr{T}, arr.start), (convert(Int64, arr.n_elems),)))
    parr!= C_NULL && c_free(parr)
    return jarr
end

export fwlite_initialize
export InputTag
export Events
export to!
export where
