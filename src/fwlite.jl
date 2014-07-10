#get the path path of the compiled C wrapper
const libfwlite = joinpath(ENV["CMSSW_BASE"], "lib", ENV["SCRAM_ARCH"], "libfwlevents_jl")
import Base.names

 #should print warnings?
const WARN = false

using DataArrays

#Try to load the FWLite libraries, warn the user in case it was impossible
#Need to do cmsenv beforehand
try
    dlopen(libfwlite)
catch e
    println("could not load $libfwlite: $e")
    path = joinpath(Pkg.dir(), "CMSSW.jl", "src", "CMSSW")
    warn("did you do 'cmsenv' CMSSW in $path ?")
    rethrow(e)
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
#TODO: this could be nicer
for symb in [:vfloat, :double, :float, :int, :uint, :string]
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
    :floats => Vector{Cfloat},
}

#TODO: do this using macros
Handle(t::Type{Vector{Cfloat}}) = Handle(new_handle_vfloat(), t)
Handle(t::Type{Float64}) = Handle(new_handle_double(), t)
Handle(t::Type{Float32}) = Handle(new_handle_float(), t)
Handle(t::Type{Int32}) = Handle(new_handle_int(), t)
Handle(t::Type{Uint32}) = Handle(new_handle_uint(), t)
Handle(t::Type{ASCIIString}) = Handle(new_handle_string(), t)
Handle(s::Symbol) = Handle(type_table[s])

#A Handle-InputTag pair
immutable Source

    #a name for the object to get from EDM
    tag::InputTag

    #contains the pointer to the heap-allocated object that will be filled form disk
    #strongly typed
    handle::Handle
end

Source(label::Symbol, instance::Symbol, process::Symbol, t::Type=Vector{Cfloat}) = Source(
    InputTag(label, instance, process), Handle(t)
)

#The primary fwlite::ChainEvent wrapper
type Events

    #List of the file names that were loaded
    fnames::Vector{String}

    #A pointer to the underlying fwlite::ChainEvent
    ev::Ptr{Void} 

    #The index of the current event
    index::Int64 

    function Events(fnames::AbstractArray)
        println("Loading events from files:")
        i = 0
        for f in fnames
            i += 1
            println("\t $i $f")
        end

        ev = ccall(
            (:new_chain_event, libfwlite),
            Ptr{Void}, (Ptr{Ptr{Uint8}}, Cuint), convert(Vector{ASCIIString}, fnames), length(fnames)
        )
        ev != C_NULL || error("could not open events: ptr=$ev")
        events = new(fnames, ev, 0)

        return events
    end
end

function list_branches(ev::Events)
    ret = Any[]
    for (dtype, label, instance, process) in names(ev)
        push!(ret, (dtype, label, instance, process))
    end
    return ret
end

Events(fname::ASCIIString) = Events([fname])

#Returns the list of products in the files
function names(ev::Events)
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

#gets the filename of the current event in a multi-file fwlite::ChainEvents
function get_current_file_name(ev::Events)
    ret = ccall(
        (:events_tfile_path, libfwlite),
        Ptr{Uint8}, (Ptr{Void}, ), ev.ev
    )
    return split(bytestring(ret), ":")[1]
end

#gets the index of the current file of the current event in a multi-file fwlite::ChainEvents
function where_file(ev::Events)
    return ccall(
        (:events_fileindex, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    ) + 1
end

#gets the linear index of the event in the file
function where_event(ev::Events)
    return int(ccall(
        (:events_eventindex, libfwlite),
        Clong, (Ptr{Void}, ), ev.ev
    )) + 1
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
            Bool, (Ptr{Void}, Clong), ev.ev, convert(Clong, n-1)
    )
    scanned || error("failed to scan to event $n")
    ev.index = n
end

#TODO: parametrize this
function Base.getindex(ev::Events, tag::InputTag, handle::Handle)
    ret = C_NULL
    if handle.t == Vector{Cfloat}
        ret = get_by_label_vfloat(ev.ev, handle.p, tag)
    elseif handle.t == Float64
        ret = get_by_label_double(ev.ev, handle.p, tag)
    elseif handle.t == Float32
        ret = get_by_label_float(ev.ev, handle.p, tag)
    elseif handle.t == Int32
        ret = get_by_label_int(ev.ev, handle.p, tag)
    elseif handle.t == Uint32
        ret = get_by_label_uint(ev.ev, handle.p, tag)
    elseif handle.t == ASCIIString
        ret = get_by_label_string(ev.ev, handle.p, tag)
    else
        error("get_by_label not defined for type $(handle.t)")
    end
    if WARN && ret == C_NULL
        warn("could not read $tag")
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
    @assert p!=C_NULL "input pointer was 0"
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
    @assert p!=C_NULL "input pointer was 0"
    #println("converting $T to julia: $p")
    arr = pointer_to_array(
        convert(Ptr{T}, p), (1,)
    )
    @assert length(arr)==1 "array was not of unit length"
    return arr[1]

end

function to_jl{T <: ASCIIString}(p::Ptr{Void}, ::Type{T})
    @assert p!=C_NULL "input pointer was 0"
    arr = bytestring(convert(Ptr{Uint8}, p))
    return arr

end

#A struct containing the Run, Lumi, Event index
immutable EventID
    run::Cuint
    lumi::Cuint
    event::Cuint
end

#gets the run,lumi,event of an event
function where(ev::Events)
    run = ccall(
        (:get_event_run, libfwlite), Clong, (Ptr{Void},), ev.ev
    )
    lumi = ccall(
        (:get_event_lumi, libfwlite), Clong, (Ptr{Void},), ev.ev
    )
    event = ccall(
        (:get_event_event, libfwlite), Clong, (Ptr{Void},), ev.ev
    )
    return (run, lumi, event)
end

# #Parallel processing related helpers
# chunk(n, c, maxn) = (sum([n]*(c-1))+1):(min(n*c, maxn))
# chunks(csize, nmax) = [chunk(csize, i, nmax) for i=1:convert(Int64, ceil(nmax/csize))]

# macro onworkers(targets, ex)
#     quote
#         @sync begin
#             for w in $targets
#                 @spawnat w eval(Main, $(Expr(:quote,ex)))
#             end
#         end
#     end
# end


# #Applied the function func across a globally(across workers in the top namespace) defined events
# function process_parallel(func::Function, events_ex::Symbol, targets::Vector{Int64}, args...)
#     newsymb = :local_tree
#     @eval @onworkers $targets const $newsymb = eval($events_ex)
#     ntree = @fetchfrom targets[1] length(eval(Main, newsymb))
#     chunksize = int(ntree / length(targets))
#     ranges = chunks(chunksize, ntree)

#     nr = 1
#     refs = RemoteRef[]
#     for r in ranges
#         nproc = targets[mod1(nr, length(targets))]
#         println("submitting chunk $(r.start):$(r.start+r.len-1) to worker $nproc, tree name=$newsymb")
#         rr = remotecall(
#             nproc,
#             _r -> map(n -> func(n, eval(Main, newsymb), args...), [_r]), r
#         )
#         push!(refs, rr)
#         nr += 1
#     end
#     return (ntree, refs)
# end

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

const CPP_JL_TYPE = {
    :double => Float64,
    :int    => Int32
}

export fwlite_initialize
export InputTag, Handle, EventID, Source
export Events
export to!, list_branches
export where, where_file, where_event
# export @onworkers, process_parallel
export get_counter_sum, passes_hlt
export get_current_file_name, print_event_id
export CPP_JL_TYPE
