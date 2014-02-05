const libplainroot = joinpath(ENV["CMSSW_BASE"], "lib", ENV["SCRAM_ARCH"], "libplainroot")
using DataArrays, DataFrames
import DataArrays.NAtype
import Base.close

typealias ColumnIndex Union(Real, String, Symbol)

import Base.Test
import Base.get, Base.cd, Base.mkdir, Base.write, Base.close, Base.fill, Base.mkpath

type TFile
    p::Ptr{Void} #pointer to TFile
    s::String #file name
end

immutable TreeBranch
    name::Ptr{Uint8} #pointer(const char *) of branch name
    dtype::Ptr{Uint8} #pointer(const char *) of branch data type
    pbranch::Ptr{Void}
end

#Call new TFile(fname, op)
function TFile(fname::String, op="")
    tf = ccall(
        (:new_tfile, libplainroot),
        Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}), string(fname), string(op)
    )
    if tf == C_NULL
        error("failed to open TFile $(string(fname))")
    end
    return TFile(tf, fname)
end

#Call TFile::Close
function Base.close(tf::TFile)
    @assert tf.p != C_NULL "TFile was already closed"
    ccall(
        (:tfile_close, libplainroot),
        Void, (Ptr{Void}, ), tf.p
    )
    tf.p = C_NULL
end


#Call TFile::Get(const char* key)
Base.get(tf::TFile, key) = ccall(
    (:tfile_get, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)
#Call TFile::mkdir(const char* key)
Base.mkdir(tf::Ptr{Void}, key) = ccall(
    (:tfile_mkdir, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf, string(key)
)

Base.mkdir(tf::TFile, key) = mkdir(tf.p, key)

Base.cd(tf::TFile, key="") = ccall(
    (:tfile_cd, libplainroot),
    Bool, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

Base.ls(tf::TFile) = ccall(
    (:tfile_ls, libplainroot),
    Void, (Ptr{Void}, ), tf.p,
)

type Branch{T}
    x::Vector{T}
    p_x::Ptr{Void} #pointer to TBranch
end

Base.write(t::Branch) = write(t.p_x)

type NABranch{T}
    value::Branch{T}
    na::Branch{Bool}
end

type TTree
    p::Ptr{Void}
    name::String
    names::Vector{String}
    coltypes::Vector{Type}
    branches::Dict{Symbol, NABranch}
    file::TFile
end

Base.write(x::Ptr{Void}) = ccall(
    (:tobject_write, libplainroot),
    Void, (Ptr{Void}, ), x
)

Base.write(tt::TTree) = write(tt.p)

#short type names used in ROOT's TBranch constructor for the leaflist
typemap = {
    Float32 => "F",
    Float64 => "D",
    Int32 => "I",
    Int64 => "L",
    Uint64 => "l",
#    ASCIIString => "C",
    Uint8 => "C",
    Bool => "O"
}


function Base.write(t::NABranch)
    write(t.value)
    write(t.na)
end

Base.write(t::TTree) = write(t.p)

NABranch{T <: Any}(x::T) = NABranch{T}(Branch(null(T)), Branch(false))

Base.fill{T}(tb::Branch{T}) = ccall(
    (:tbranch_fill, libplainroot),
    Void, (Ptr{Void}, ), tb.p_x
)

function setval!(b, x)
    b.na.x[1] = isna(x)
    b.value.x[1] = isna(x) ? null(T) : x
    fill(b.na)
    fill(b.value)
end

attach{T}(b::Branch{T}, tree::TTree, name) = attach(b, tree.p, name)

function attach{T}(b::NABranch{T}, tree::TTree, name)
    attach(b.value, tree, name)
    attach(b.na, tree, "$(name)_ISNA")
    tree = TTree(tree.file, tree.name)      
end

function attach{T}(b::Branch{T}, tree_p::Ptr{Void}, name)
    global typemap
    p = ccall(
        (:ttree_branch, libplainroot),
        Ptr{Void}, (Ptr{Void}, Ptr{Uint8}, Ptr{Ptr{Void}}, Ptr{Uint8}), tree_p, string(name), pointer(b.x), "$name/$(typemap[T])"
    )
    b.p_x = p
    ccall(
        (:ttree_set_branch_address, libplainroot),
        Cint, (Ptr{Void}, Ptr{Ptr{Void}}, Ptr{Uint8}),
        tree_p, pointer(b.x), string(name)
    )
end

Branch{T <: Number}(defval::T) = Branch{T}(T[defval], C_NULL)
#Branch{T <: ASCIIString}(defval::T) = Branch{T}([defval], C_NULL)
Branch{T <: ASCIIString}(defval::T) = Branch{Uint8}(convert(Vector{Uint8}, defval), C_NULL)
Branch{T <: Any}(defval::T) = error("not implemented")

null{T <: Number}(::Type{T}) = convert(T, 0.0)::T
null{T <: String}(::Type{T}) = bytestring(convert(Vector{Uint8}, zeros(512)))
null{T <: Any}(::Type{T}) = error("not implemented for $T")
null{T <: NAtype}(::Type{T}) = NA

function TTree(
    tf::TFile, name,
    names=Any[],
    coltypes=Any[]
    )
    tf.p != C_NULL || error("TFile $(tf) was not opened successfully")
    tree = get(tf, name)
    
    
    if tree == C_NULL
        #println("creating new TTree $name")
        tree = ccall(
            (:new_ttree, libplainroot),
            Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(name)
        )
    else
        brs = ROOT.ttree_get_branches(tree)
        for (name, dt) in brs
            contains(name, "_ISNA") && continue
            name in names && continue #duplicate column
            push!(names, name)
            push!(coltypes, dt)
        end
    end
    assert(tree != C_NULL)

    branches = Dict{Symbol, NABranch}()

    for (cn, ct) in zip(names, coltypes)
        #println(cn, " ", ct)
        cn = string(cn)
        x = Branch(null(ct))
        na = Branch(false) #the branch which signifies if a value is available

        a = attach(x, tree, cn)
        b = attach(na, tree, "$(cn)_ISNA")

        branches[symbol(cn)] = NABranch(x, na)
    end
    return TTree(
        tree, name, convert(Vector{ASCIIString}, names),
        convert(Vector{Type}, coltypes),
        branches, tf
    )
end

function strcpy(a, b)
    assert(length(b)<length(a))
    unsafe_copy!(
        pointer(convert(Vector{Uint8}, a)),
        pointer(vcat(convert(Vector{Uint8}, b), [convert(Uint8,0)])),
        length(b)
    )
end

function Base.setindex!{T <: ASCIIString}(tree::TTree, x::T, s::Symbol, tt::Type{T})
    br = tree.branches[s]
    #T = typeof(br).parameters[1]
    strcpy(br.value.x, x)
    br.na.x[1] = false
end

function Base.setindex!{T <: Number}(tree::TTree, x::NAtype, s::Symbol, tt::Type{T})
    @assert s in keys(tree.branches)
    br = tree.branches[s]::NABranch{T}
    br.value.x[1] = null(T)::T
    br.na.x[1] = true
end

function Base.setindex!{T <: Number}(tree::TTree, x::T, s::Symbol, tt::Type{T})
    @assert s in keys(tree.branches)
    br = tree.branches[s]::NABranch{T}
    br.value.x[1] = x
    br.na.x[1] = false
end

#function Base.setindex!{T <: NAtype}(tree::TTree, x::T, s::Symbol)
#    br = tree.branches[s]
#    for i=1:length(br.value.x)
#        br.value.x[i] = 0
#    end
#    br.na.x[1] = true
#end

function coltype{T <: ColumnIndex}(tree::TTree, cn::T)
    br = tree.branches[symbol(cn)]
    X = typeof(br).parameters[1]::Type
    return X
end

function Base.getindex{T <: ColumnIndex, K <: Number}(tree::TTree, s::T, k::Type{K})
    const br = tree.branches[symbol(s)]::NABranch{K}
    x = br.value.x[1]::K
    return x
end

function Base.getindex{T <: ColumnIndex, K <: Uint8}(tree::TTree, s::T, k::Type{K})
    const br = tree.branches[symbol(s)]::NABranch{K}
    return convert(ASCIIString, bytestring(br.value.x[1:(indmin(br.value.x)-1)]::Vector{Uint8}))
end

function Base.getindex{T <: ColumnIndex}(tree::TTree, s::T, checkna=true)
    br = tree.branches[symbol(s)]
    const bt = typeof(br).parameters[1]
    
    if checkna
        na = br.na.x[1]::Bool
        return (na ? NA : tree[s, bt])
    else
        return tree[s, bt]::bt
    end
end

function fill!(tree::TTree)
    return ccall(
        (:ttree_fill, libplainroot),
        Clong, (Ptr{Void}, ), tree.p,
    )
end

function set_branch_status!(tree::TTree, brstring::ASCIIString, status::Bool)
    return ccall(
        (:ttree_set_branch_status, libplainroot),
        Void, (Ptr{Void}, Ptr{Uint8}, Bool), tree.p, brstring, status
    )
end

function getentry!(tree::TTree, n::Int64)
    return ccall(
        (:ttree_get_entry, libplainroot),
        Clong, (Ptr{Void}, Clong), tree.p, n-1
    )
end

function reset_cache!(tree::TTree)
    return ccall(
        (:ttree_reset_cache, libplainroot),
        Void, (Ptr{Void}, ), tree.p
    )
end

function add_cache!(tree::TTree, branches::ASCIIString)
    return ccall(
        (:ttree_add_cache, libplainroot),
        Void, (Ptr{Void}, Ptr{Uint8}), tree.p, branches
    )
end



function Base.length(tree::TTree)
    @assert tree.p != C_NULL
    @assert tree.file.p != C_NULL

    return ccall(
        (:ttree_get_entries, libplainroot),
        Clong, (Ptr{Void}, ), tree.p
    )
end

function writetree(fn, df::AbstractDataFrame;progress=true)
    tf = TFile(fn, "RECREATE")
    const tree = TTree(
        tf, "dataframe",
        map(string, names(df)),
        types(df)
    )
    n = nrow(df)

    const nts = convert(
        Vector{(Symbol, Type)},
        collect(zip(
            map(symbol, names(df)),
            types(df)
    )))
    for i=1:n
        
        #progress && (i % 1000 == 0) && print(".")
        #
        #if progress && (i % (int(n/10.0)+1) == 0)
        #    println(10 * i/(int(n/10.0)), "%: $i ", toq())
        #    tic()
        #end
        
        for (cn::Symbol, ct::Type) in nts
            tree[cn, ct] = df[i, cn]
        end
        x=fill!(tree)
        #x<=0 || error("could not TTree::Fill row $i")
    end
    write(tree)
    close(tf)
end

function readtree(fn; progress=false, maxrows=0)
    tf = TFile(fn, "READ")
    tree = TTree(tf, "dataframe")
    #println(tree.names)

    #reset_cache!(tree)
    #add_cache!(tree, "*")
    n = maxrows > 0 ? maxrows : length(tree)
    n = min(length(tree), n)
    progress && tic()
    progress && println("creating DataFrame with $n rows, $(length(tree.names)) columns")
    df = DataFrame(tree.coltypes, map(symbol, tree.names), n)
    progress && toc() 
    cns = map(symbol, names(df)) 
    progress && println("looping over $n events")
    for i=1:n
        if progress && (i % 1000 == 0)
            print(".")
        end
        if progress && (i % int(n/10) == 0)
            println(10 * i/(int(n/10)), "%: $i ", toq())
            tic()
        end
        getentry!(tree, i)
        for cn in cns
            df[i, cn] = tree[cn]
        end
    end
    close(tf)
    return df
end


plain_type_table = {
    "Float_t"=>Float32,
    "Double_t"=>Float64,
    "Int_t"=>Int32,
    "Long64_t"=>Int64,
    "ULong64_t"=>Uint64,
    "Char_t"=>ASCIIString,
    "Bool_t"=>Bool
}

function to_arr{T <: TreeBranch}(arr::CArray, ::Type{T})
    p = pointer(TreeBranch, arr.start)
    struct_arr = pointer_to_array(p, (convert(Int64, arr.n_elems),))
    out = Any[]
    for s in struct_arr
        dt = bytestring(s.dtype)
        name = bytestring(s.name)

        c_free(s.name)
        c_free(s.dtype)

        if !(dt in keys(plain_type_table))
            warn("branch $(name):$(dt) not handled")
            continue
        end
        t = plain_type_table[dt]
        push!(out, (name, t))
    end

    return out
end

function ttree_get_branches(ttree::Ptr{Void})
    out = ccall(
        (:ttree_get_branches, libplainroot),
        Ptr{CArray}, (Ptr{Void}, ), ttree
    )
    arr = unsafe_load(out)
    return to_arr(arr, TreeBranch)
end

function removeinf(arr)
    for i=1:length(arr)
        if arr[i]==-Inf
            arr[i] = -e^10#nextfloat(-Inf)
        end
        if arr[i]==Inf
            arr[i] = e^10#prevfloat(Inf)
        end
    end
    return arr
end

function new_th1d(
    name::ASCIIString,
    edges::AbstractVector, #low_under, low_1, low_2, ... , low_over, high_over
    bins::AbstractVector, #under, c1, c2, ... , over
    errors::AbstractVector,
    labels::AbstractVector=[]
)
    @assert length(edges)==length(bins)+1
    @assert length(edges)==length(errors)+1

    #remove underflow low and overflow high edges
    edges = deepcopy(edges[2:length(edges)-1])

    removeinf(edges)
    @assert !any(isnan(edges))

    if length(labels)==0
        labels = [@sprintf("[%.2f,%.2f)", edges[i-1], edges[i]) for i=2:length(edges)]
    end
    @assert length(edges)==length(labels)+1

    for i=1:length(edges)
        if edges[i]==-Inf
            edges[i] = -e^10#nextfloat(-Inf)
        end
        if edges[i]==Inf
            edges[i] = e^10#prevfloat(Inf)
        end
        if isnan(edges[i])
            error("edges must not contain nan: ", join(edges, ","))
        end
    end

    hi = ccall(
       (:new_th1d, libplainroot),
       Ptr{Void},
       (Ptr{Uint8}, Cuint, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Ptr{Uint8}}),
       name, length(edges),
       convert(Vector{Float64}, edges),
       convert(Vector{Float64}, bins),
       convert(Vector{Float64}, errors),
       convert(Vector{ASCIIString}, labels)
    )
    return hi
end

function new_th2d(
    name::ASCIIString,
    edges_x::Array{Float64, 1},
    edges_y::Array{Float64, 1},
    bins::Array{Float64, 2},
    errors::Array{Float64, 2},
    labels_x=[],
    labels_y=[],
)
    @assert size(bins)==size(errors)
    nx, ny = size(bins)
    @assert length(edges_x) == nx+1 "$(length(edges_x)) != $(nx+1) \n $edges_x"
    @assert length(edges_y) == ny+1 "$(length(edges_y)) != $(ny+1) \n $edges_x"

    edges_x = deepcopy(edges_x[2:length(edges_x)-1])
    edges_y = deepcopy(edges_y[2:length(edges_y)-1])

    removeinf(edges_x)
    removeinf(edges_y)

    @assert !any(isnan(edges_x))
    @assert !any(isnan(edges_y))

    if length(labels_x)==0
        labels_x = [@sprintf("x=[%.2f,%.2f)", edges_x[i-1], edges_x[i]) for i=2:length(edges_x)]
    end
    if length(labels_y)==0
        labels_y = [@sprintf("y=[%.2f,%.2f)", edges_y[i-1], edges_y[i]) for i=2:length(edges_y)]
    end
    @assert length(edges_x)==length(labels_x)+1
    @assert length(edges_y)==length(labels_y)+1

    pbins = [pointer(bins[i,:]) for i=1:nx]
    perrs = [pointer(errors[i,:]) for i=1:nx]
    hi = ccall(
       (:new_th2d, libplainroot),
       Ptr{Void},
       (
        Ptr{Uint8},
        Cuint, Cuint,
        Ptr{Cdouble}, Ptr{Cdouble},
        Ptr{Ptr{Cdouble}}, Ptr{Ptr{Cdouble}},
        Ptr{Ptr{Uint8}}, Ptr{Ptr{Uint8}}
        ),
       name, length(edges_x), length(edges_y),
       edges_x, edges_y, pbins, perrs,
       convert(Vector{ASCIIString}, labels_x), convert(Vector{ASCIIString}, labels_y)
    ) 

end

function set_axis_label(h::Ptr{Void}, label, n=1)
    ccall(
           (:set_axis_label, libplainroot),
           Void,
           (
            Ptr{Void},
            Cint,
            Ptr{Uint8}
            ),
           h, n, convert(ASCIIString, label),
        ) 
end

export close
export writetree, readtree, ColumnIndex, coltype
export set_branch_status!, reset_cache!, add_cache!
export new_th1d, new_th2d, TFile
