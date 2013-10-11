const libplainroot = joinpath(Pkg.dir(), "ROOT.jl", "deps", "ntuple", "CMSSW", "lib", ENV["SCRAM_ARCH"], "libplainroot")
using DataFrames
import Base.Test


type TFile
    p::Ptr{Void}
    s::String
end

function TFile(fname, op)
    TFile(ccall(
        (:new_tfile, libplainroot),
        Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}), string(fname), string(op)
    ), fname)
end

close(tf::TFile) = ccall(
    (:tfile_close, libplainroot),
    Void, (Ptr{Void}, ), tf.p
)

get(tf::TFile, key) = ccall(
    (:tfile_get, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

type TTree
    p::Ptr{Void}
    name::String
    colnames::Vector{String}
    coltypes::Vector{Type}
    branches::Associative
end

typemap = {
    Float32 => "F",
    Float64 => "D",
    Int32 => "I",
    Int64 => "L",
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
    ccall(
        (:ttree_set_branch_address, libplainroot),
        Void, (Ptr{Void}, Ptr{Ptr{Void}}, Ptr{Uint8}),
        tree_p, pointer(b.x), string(name)
    )
end

# function attach2{T}(b::Branch{T}, tree_p::Ptr{Void}, name)
#     global typemap
#     p = ccall(
#         (:new_tbranch, libplainroot),
#         Ptr{Void}, (Ptr{Void}, Ptr{Uint8}, Ptr{Ptr{Void}}, Ptr{Uint8}), tree_p, string(name), pointer(b.x), "$name/$(typemap[T])"
#     )
#     b.p_x = p
# end

Branch{T <: Number}(defval::T) = Branch{T}([defval], C_NULL)
#Branch{T <: ASCIIString}(defval::T) = Branch{T}([defval], C_NULL)
Branch{T <: ASCIIString}(defval::T) = Branch{Uint8}(convert(Vector{Uint8}, defval), C_NULL)
Branch{T <: Any}(defval::T) = error("not implemented")

null{T <: Number}(::Type{T}) = convert(T, 0.0)
null{T <: String}(::Type{T}) = bytestring(convert(Vector{Uint8}, zeros(512)))
null{T <: Any}(::Type{T}) = error("not implemented for $T")

function TTree(tf::TFile, name, colnames, coltypes)

    tree = get(tf, name)
    if tree == C_NULL
        tree = ccall(
            (:new_ttree, libplainroot),
            Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(name)
        )
    end
    assert(tree != C_NULL)

    branches = Dict{String, NABranch}()

    for (cn, ct) in zip(colnames, coltypes)
        x = Branch(null(ct))
        na = Branch(true)

        attach(x, tree, cn)
        attach(na, tree, "$(cn)_ISNA")

        branches[cn] = NABranch(x, na)
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

function Base.setindex!(tree::TTree, x::String, s::Any)
    br = tree.branches[string(s)]
    T = typeof(br).parameters[1]
    strcpy(br.value.x, x)
    br.na.x[1] = false
end

function Base.setindex!(tree::TTree, x::Number, s::Any)
    br = tree.branches[string(s)]
    T = typeof(br).parameters[1]
    br.value.x[1] = convert(T, x)
    br.na.x[1] = false
end

function Base.setindex!(tree::TTree, x::NAtype, s::Any)
    br = tree.branches[string(s)]
    T = typeof(br).parameters[1]
    for i=1:length(br.value.x)
        br.value.x[i] = 0
    end
    br.na.x[1] = true
end

function Base.getindex(tree::TTree, s::Any)
    br = tree.branches[string(s)]
    T = typeof(br).parameters[1]
    if T <: Uint8
        x = bytestring(br.value.x[1:(indmin(br.value.x)-1)])
    elseif T <: Number 
        x = br.value.x[1] 
    else
        error("not implemented")
    end
    na = br.na.x[1]
    return na ? NA : x
end

function fill!(tree::TTree)
    return ccall(
        (:ttree_fill, libplainroot),
        Clong, (Ptr{Void}, ), tree.p,
    )
end

function getentry!(tree::TTree, n::Int64)
    return ccall(
        (:ttree_get_entry, libplainroot),
        Clong, (Ptr{Void}, Clong), tree.p, n
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
    for i=1:nrow(df)
        for cn in colnames(df)
            tree[symbol(cn)] = NA #zero out (for strings)
            tree[symbol(cn)] = df[i, cn]
        end
        fill!(tree)
    end
    close(tf)
end

function readtree(fn)
    tf = TFile(fn, "READ")
    tree = TTree(tf, "dataframe", {"a", "b"}, {Float64, ASCIIString})
    n = length(tree)
    #df = DataFrame({x=>y for (x,y) in zip(tree.colnames, tree.coltypes)}, n)
    df = DataFrame(tree.coltypes, convert(Vector{ByteString}, tree.colnames), n)
    for i=1:n
        getentry!(tree, i-1)
        for cn in colnames(df)
            df[i, cn] = tree[symbol(cn)]
        end
    end
    close(tf)
    return df
end

df = readtable("/Users/joosep/Documents/stpol/data/oct3/output_172.csv.gz")
writetree("test.root", df)
# df = DataFrame(
#     a=DataVector[0.1, 1.2, 2.3, 3.4, 4.5, NA, 5.6],
#     b=DataVector["asd", "bds", "csd", "dsa", "sss", NA, "lol"]
# )
# writetree(df, "test.root")
# df2 = readtree("test.root")


# println(df2)
# println(df .== df2)
# tf = TFile("test.root", "RECREATE")
# tree = TTree(tf, "my_tree", {"col1", "col2", "col3"}, {Float32, Int64, ASCIIString})
# for i=1:1000
#     tree[:col1] = i
#     tree[:col2] = i
#     tree[:col3] = string("rohelisekoerasaba_$i")
#     nb = fill!(tree)
# end
# tree[:col1] = NA
# tree[:col3] = NA
# fill!(tree)
# close(tf)

# tf = TFile("test.root", "READ")
# tree = TTree(tf, "my_tree", {"col1", "col2", "col3"}, {Float32, Int64, ASCIIString})
# for i=0:(length(tree)-1)
#     y = getentry!(tree, i)
#     x = tree[:col1]
#     println("col3=",tree[:col3])
# end
# close(tf)
