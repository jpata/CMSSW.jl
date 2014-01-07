const libplainroot = joinpath(ENV["CMSSW_BASE"], "lib", ENV["SCRAM_ARCH"], "libplainroot")
using DataFrames

typealias ColumnIndex Union(Real, String, Symbol)

import Base.Test

type TFile
    p::Ptr{Void}
    s::String
end

function TFile(fname::ASCIIString, op="")
    tf = ccall(
        (:new_tfile, libplainroot),
        Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}), string(fname), string(op)
    )
    if tf == C_NULL
        error("failed to open TFile $(string(fname))")
    end
    return TFile(tf, fname)
end

close(tf::TFile) = ccall(
    (:tfile_close, libplainroot),
    Void, (Ptr{Void}, ), tf.p
)

get(tf::TFile, key) = ccall(
    (:tfile_get, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

mkdir(tf::TFile, key) = ccall(
    (:tfile_mkdir, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

cd(tf::TFile, key) = ccall(
    (:tfile_cd, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

type TTree
    p::Ptr{Void}
    name::String
    colnames::Vector{String}
    coltypes::Vector{Type}
    branches::Associative
end

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

type Branch{T}
    x::Vector{T}
    p_x::Ptr{Void}
end

type NABranch{T}
    value::Branch{T}
    na::Branch{Bool}
end

function attach{T}(b::Branch{T}, tree_p::Ptr{Void}, name)
    global typemap
    p = ccall(
        (:ttree_branch, libplainroot),
        Ptr{Void}, (Ptr{Void}, Ptr{Uint8}, Ptr{Ptr{Void}}, Ptr{Uint8}), tree_p, string(name), pointer(b.x), "$name/$(typemap[T])"
    )
    b.p_x = p
    return ccall(
        (:ttree_set_branch_address, libplainroot),
        Cint, (Ptr{Void}, Ptr{Ptr{Void}}, Ptr{Uint8}),
        tree_p, pointer(b.x), string(name)
    )
end

Branch{T <: Number}(defval::T) = Branch{T}(T[defval], C_NULL)
#Branch{T <: ASCIIString}(defval::T) = Branch{T}([defval], C_NULL)
Branch{T <: ASCIIString}(defval::T) = Branch{Uint8}(convert(Vector{Uint8}, defval), C_NULL)
Branch{T <: Any}(defval::T) = error("not implemented")

null{T <: Number}(::Type{T}) = convert(T, 0.0)
null{T <: String}(::Type{T}) = bytestring(convert(Vector{Uint8}, zeros(512)))
null{T <: Any}(::Type{T}) = error("not implemented for $T")
null{T <: NAtype}(::Type{T}) = NA

function TTree(tf::TFile, name, colnames=Any[], coltypes=Any[])
    tf.p != C_NULL || error("TFile $(tf) was not opened successfully")
    tree = get(tf, name)
    if tree == C_NULL
        tree = ccall(
            (:new_ttree, libplainroot),
            Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(name)
        )
    else
        brs = ROOT.ttree_get_branches(tree)
        for (name, dt) in brs
            contains(name, "_ISNA") && continue
            push!(colnames, name)
            push!(coltypes, dt)
        end
    end
    assert(tree != C_NULL)

    branches = Dict{Symbol, NABranch}()


    for (cn, ct) in zip(colnames, coltypes)
        #println(cn, " ", ct)
        x = Branch(null(ct))
        na = Branch(false) #the branch which signifies if a value is available

        a = attach(x, tree, cn)
        b = attach(na, tree, "$(cn)_ISNA")

        branches[symbol(cn)] = NABranch(x, na)
    end
    return TTree(tree, name, convert(Vector{String}, colnames), convert(Vector{Type}, coltypes), branches)
end

function strcpy(a, b)
    assert(length(b)<length(a))
    unsafe_copy!(
        pointer(convert(Vector{Uint8}, a)),
        pointer(vcat(convert(Vector{Uint8}, b), [convert(Uint8,0)])),
        length(b)
    )
end

function Base.setindex!{T <: ASCIIString}(tree::TTree, x::T, s::Symbol)
    br = tree.branches[s]
    #T = typeof(br).parameters[1]
    strcpy(br.value.x, x)
    br.na.x[1] = false
end

function Base.setindex!{T <: Number}(tree::TTree, x::T, s::Symbol)
    br = tree.branches[s]
    #T = typeof(br).parameters[1]
    #br.value.x[1] = convert(T, x)
    br.value.x[1] = x
    br.na.x[1] = false
end

function Base.setindex!{T <: NAtype}(tree::TTree, x::T, s::Symbol)
    br = tree.branches[s]
    for i=1:length(br.value.x)
        br.value.x[i] = 0
    end
    br.na.x[1] = true
end

function coltype{T <: ColumnIndex}(tree::TTree, cn::T)
    br = tree.branches[symbol(cn)]
    T = typeof(br).parameters[1]
    return T
end

function Base.getindex{T <: ColumnIndex}(tree::TTree, s::T, checkna=true)
    br = tree.branches[symbol(s)]
    const bt = typeof(br).parameters[1]

    if bt <: Uint8 #is string
        x = bytestring(br.value.x[1:(indmin(br.value.x)-1)])
    elseif bt <: Number 
        x = br.value.x[1] 
    else
        error("not implemented")
    end

    if checkna
        na = br.na.x[1]
        return (na ? NA : x)
    else
        return x
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
    return ccall(
        (:ttree_get_entries, libplainroot),
        Clong, (Ptr{Void}, ), tree.p
    )
end

function writetree(fn, df::DataFrame)
    tf = TFile(fn, "RECREATE")
    tree = TTree(tf, "dataframe", colnames(df), coltypes(df))
    #reset_cache!(tree)
    #add_cache!(tree, "*")
    for i=1:nrow(df)
        for cn in colnames(df)
            tree[symbol(cn)] = NA #zero out (for strings)
            tree[symbol(cn)] = df[i, cn]
        end
        fill!(tree)
    end
    close(tf)
end

function readtree(fn; progress=false)
    tf = TFile(fn, "READ")
    tree = TTree(tf, "dataframe")
    #reset_cache!(tree)
    #add_cache!(tree, "*")
    n = length(tree)
    println("creating DataFrame with $n rows, $(length(tree.colnames)) columns")
    df = DataFrame(tree.coltypes, convert(Vector{ByteString}, tree.colnames), n)
    cns = map(symbol, colnames(df)) 
    println("looping over $n events")
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

immutable TreeBranch
    name::Ptr{Uint8}
    dtype::Ptr{Uint8}
    pbranch::Ptr{Void}
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

export writetree, readtree, ColumnIndex, coltype
export set_branch_status!, reset_cache!, add_cache!
