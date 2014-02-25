
immutable TreeBranch
    name::Ptr{Uint8} #pointer(const char *) of branch name
    dtype::Ptr{Uint8} #pointer(const char *) of branch data type
    pbranch::Ptr{Void}
end

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

Base.write(tt::TTree) = write(tt.p)


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
        brs = CMSSW.ttree_get_branches(tree)
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
        eltypes(df)
    )
    n = nrow(df)

    const nts = convert(
        Vector{(Symbol, Type)},
        collect(zip(
            map(symbol, names(df)),
            eltypes(df)
    )))
    for i=1:n

        for (cn::Symbol, ct::Type) in nts
            tree[cn, ct] = df[i, cn]
        end
        x=fill!(tree)
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
