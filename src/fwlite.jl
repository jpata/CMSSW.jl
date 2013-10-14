const libfwlite = joinpath(Pkg.dir(), "ROOT.jl", "deps", "ntuple", "CMSSW", "lib", ENV["SCRAM_ARCH"], "libfwlevents_jl")

using DataFrames

#Try to load the FWLite libraries, warn the user in case it was impossible
#Need to do cmsenv beforehand
try
    dlopen(libfwlite)
catch e
    println("could not load $libfwlite: $e")
    path = joinpath(Pkg.dir(), "ROOT.jl", "src", "CMSSW")
    warn("did you do 'cmsenv' CMSSW in $path ?")
    rethrow(e)
end

#A C struct for a variable size array
immutable CArray
    start::Ptr{Ptr{Void}} #Pointer to the start of the array
    size::Cint #Size of an element in the array
    n_elems::Cint #Length of the array
end

#A wrapper for edm::InputTag
immutable InputTag
    p::Ptr{Void} #Pointer to the underlying InputTag object
    label::Symbol #The module that produced this object
    instance::Symbol #The product in this module
    process::Symbol #THe cmsRun Process that produced this object

    InputTag(label::Symbol, instance::Symbol, process::Symbol) = new(
        ccall(
            (:new_inputtag, libfwlite),
            Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}, Ptr{Uint8}), string(label), string(instance), string(process)
        ), label, instance, process
    )
end

#Create the methods for creating fwlite::Handle objects and getting objects by label using fwlite::Handle::getByLabel
for symb in [:vfloat, :double, :float, :int]
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

#Initialize the FWLite libraries
function fwlite_initialize()
    out = ccall(
        (:initialize, libfwlite),
        Void, (),
    )
    return out
end

#A Wrapper for fwlite::Handle<T>
immutable Handle
    p::Ptr{Void} #The poiter to the underlying fwlite::Handle
    t::Type #The Handle datatype
end

const type_table = {
    :floats => Vector{Cfloat}
}

function Handle(t::Type)
    if t==Vector{Cfloat}
        hp = new_handle_vfloat()
        return Handle(hp, t)
    elseif t==Float64
        hp = new_handle_double()
        return Handle(hp, t)
    elseif t==Float32
        hp = new_handle_float()
        return Handle(hp, t)
    elseif t==Int32
        hp = new_handle_int()
        return Handle(hp, t)
    else
        error("Handle not defined for type $t")
    end
end

Handle(s::Symbol) = Handle(type_table[s])

#A Handle-InputTag pair
immutable Source
    tag::InputTag
    handle::Handle
end

Source(label::Symbol, instance::Symbol, process::Symbol, t::Type=Vector{Cfloat}) = Source(
    InputTag(label, instance, process), Handle(t)
)

#The primary fwlite::ChainEvent wrapper
type Events
    fnames::Vector{String} #List of the file names that were loaded
    ev::Ptr{Void} #A pointer to the underlying fwlite::ChainEvent
    index::Int64 #The index of the current event

    function Events(fnames)
        println("Loading events from files:")
        for f in fnames
            println("\t $f")
        end
        ev = ccall(
            (:new_chain_event, libfwlite),
            Ptr{Void}, (Ptr{Ptr{Uint8}}, Cuint), convert(Vector{ASCIIString}, fnames), length(fnames)
        )
        events = new(fnames, ev, 0)

        # Get the list of products in the files
        # for (dtype, label, instance, process) in get_branches(events)
        #     try
        #         #events.tags[(label, instance, process)] = (InputTag(label, instance, process), Handle(dtype))
        #     catch e
        #         #warn("tag $dtype, $label, $instance, $process not created: $e")
        #     end
        # end
        return events
    end
end

function list_branches(ev::Events)
    for (dtype, label, instance, process) in get_branches(ev)
        println("$label:$instance:$process -> $dtype")
    end
end

Events(fname::ASCIIString) = Events([fname])

#Returns the list of products in the files
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

#Gets the run, lumi, event ID of the current event 
function where_file(ev::Events)
    return ccall(
        (:events_fileindex, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    ) + 1
end

#Gets the number of events in the files
function Base.length(ev::Events)
    return ccall(
        (:events_size, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    )
end

#Scans to an event with a global(across files) index n
function to!(ev::Events, n::Integer)
    scanned = ccall(
            (:events_to, libfwlite),
            Bool, (Ptr{Void}, Clong), ev.ev, n-1
    )
    scanned || error("failed to scan to event $n")
    ev.index = n
end

function Base.getindex(ev::Events, tag::InputTag, handle::Handle)
    ret = C_NULL
    if handle.t == Vector{Cfloat}
        ret = get_by_label_vfloat(ev.ev, handle.p, tag)
    elseif handle.t == Float64
        ret = get_by_label_double(ev.ev, handle.p, tag)
    elseif handle.t == Int32
        ret = get_by_label_int(ev.ev, handle.p, tag)
    else
        error("get_by_label not defined for type $(handle.t)")
    end
    return ret != C_NULL ? to_jl(ret, handle.t) : NA
end

function Base.getindex(ev::Events, s::Source)
    return ev[s.tag, s.handle]
end

#Converts C++ objects to Julia Arrays
#The memory is not copied explicitly, thus subsequent events overwrite the contents of the array
#Currently only implemented for std::vector<float>
function to_jl{T <: Vector{Cfloat}}(p::Ptr{Void}, ::Type{T})
    assert(p!=C_NULL, "input pointer was 0")
    parr = ccall(
            (:convert_vector_vfloat, libfwlite),
            Ptr{CArray}, (Ptr{Void}, ), p
    )
    (parr == C_NULL) && throw("output pointer was 0")
    arr = unsafe_load(parr)
    jarr = pointer_to_array(
        convert(Ptr{Cfloat}, arr.start), (convert(Int64, arr.n_elems),)
    )
    parr != C_NULL && c_free(parr)
    return jarr
end

function to_jl{T <: Number}(p::Ptr{Void}, ::Type{T})
    assert(p!=C_NULL, "input pointer was 0")
    #println("converting $T to julia: $p")
    arr = pointer_to_array(
        convert(Ptr{T}, p), (1,)
    )
    assert(length(arr)==1)
    return arr[1]

end

#A struct containing the Run, Lumi, Event index
immutable EventID
    run::Cuint
    lumi::Cuint
    event::Cuint
end

#gets the run,lumi,event of an event
function where(ev::Events)
    r = ccall(
        (:get_event_id, libfwlite), EventID, (Ptr{Void},), ev.ev
    )
    return (convert(Int64, r.run), convert(Int64, r.lumi), convert(Int64, r.event))
end

#Parallel processing related helpers
chunk(n, c, maxn) = (sum([n]*(c-1))+1):(min(n*c, maxn))
chunks(csize, nmax) = [chunk(csize, i, nmax) for i=1:convert(Int64, ceil(nmax/csize))]

macro onworkers(targets, ex)
    quote
        @sync begin
            for w in $targets
                @spawnat w eval(Main, $(Expr(:quote,ex)))
            end
        end
    end
end


#Applied the function func across a globally(across workers in the top namespace) defined events
function process_parallel(func::Function, events_ex::Symbol, targets::Vector{Int64}, args...)
    newsymb = :local_tree
    @eval @onworkers $targets const $newsymb = eval($events_ex)
    ntree = @fetchfrom targets[1] length(eval(Main, newsymb))
    chunksize = int(ntree / length(targets))
    ranges = chunks(chunksize, ntree)

    nr = 1
    refs = RemoteRef[]
    for r in ranges
        nproc = targets[mod1(nr, length(targets))]
        println("submitting chunk $(r.start):$(r.start+r.len-1) to worker $nproc, tree name=$newsymb")
        rr = remotecall(
            nproc,
            _r -> map(n -> func(n, eval(Main, newsymb), args...), [_r]), r
        )
        push!(refs, rr)
        nr += 1
    end
    return (ntree, refs)
end

#gets the total counter value of a named edm::MergeableCounter across files
function get_counter_sum{T <: String}(fnames::AbstractVector{T}, cname)
    return ccall(
        (:get_counter_sum, libfwlite), Clong, (Ptr{Ptr{Uint8}}, Cuint, Ptr{Uint8}),
        convert(Vector{ASCIIString}, fnames), length(fnames), string(cname)
    )
end

function passes_hlt{T <: String}(ev::Events, hlts::AbstractVector{T})
    return ccall(
        (:passes_triggers, libfwlite), Bool, (Ptr{Void}, Ptr{Ptr{Uint8}}, Cuint),
        ev.ev, convert(Vector{ASCIIString}, hlts), length(hlts)
    )
end

export fwlite_initialize
export InputTag, Handle, EventID, Source
export Events
export to!, list_branches
export where, where_file
export @onworkers, process_parallel
export get_counter_sum, passes_hlt
