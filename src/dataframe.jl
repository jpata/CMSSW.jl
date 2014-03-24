using CMSSW
using DataFrames
import DataFrames.nrow, DataFrames.ncol, DataFrames.names, DataFrames.types
import Base.getindex, Base.setindex!, Base.display, Base.show

#wrapper around TTree that supports getindex functionality
#tree branches must be of elementary type
#setindex currently not supported: http://root.cern.ch/root/roottalk/roottalk97/1192.html
type TreeDataFrame <: AbstractDataFrame
    file::CMSSW.TFile
    tree::CMSSW.TTree
    doget::Bool
end

const modetable = {"r"=>"READ", "rw"=>"UPDATE", "w"=>"RECREATE"}
function TreeDataFrame(fn::String, mode="r")
    file = CMSSW.TFile(string(fn), modetable[mode])
    tree = CMSSW.TTree(file, "dataframe")
    return TreeDataFrame(file, tree, true)
end

TreeDataFrame(df::TreeDataFrame) = TreeDataFrame(df.file.s)

DataFrames.nrow(df::TreeDataFrame) = length(df.tree)
DataFrames.ncol(df::TreeDataFrame) = length(df.tree.names)
DataFrames.names(df::TreeDataFrame) = collect(map(symbol, df.tree.names))

function Base.show(io::IO, df::TreeDataFrame) 
    show(io, df[1:5, :])
end

function colname{T <: Integer}(df::TreeDataFrame, col_ind::T)
    (col_ind > 0 && col_ind <= length(names(df))) || error("index out of range: $col_ind ! in [1, $(length(names(df)))]") 
    return names(df)[col_ind]
end

function colname{T <: Symbol}(df::TreeDataFrame, col_ind::T)
    return string(col_ind) 
end

function coltype(df::TreeDataFrame, col_ind::Integer)
    cts = df.tree.coltypes
    return cts[col_ind]
end

function coltype(df::TreeDataFrame, col::Symbol)
    col in names(df) || error("$col is not in dataframe columns: $(names)")
    ci = findfirst(names(df), col)
    coltype(df, ci)
end

DataFrames.types(df::TreeDataFrame) = [coltype(df, x) for x=1:length(names(df))] 

function Base.getindex{R <: Real}(df::TreeDataFrame, row_ind::R, col_ind::ColumnIndex, doget=false)
    cn = colname(df, col_ind)
     
    (doget || df.doget) && CMSSW.getentry!(df.tree, row_ind)
    return df.tree[cn]
end

Base.show(io::IO, df::TreeDataFrame) = show(io, df[1:min(nrow(df),10), :])

function Base.getindex{T <: ColumnIndex}(df::TreeDataFrame, row_ind::Real, col_inds::AbstractVector{T})
    DataFrame({colname(df, ci) => df[row_ind, ci] for ci in col_inds})
end

function Base.getindex(df::TreeDataFrame, col_ind::ColumnIndex)
    ret = DataArray(coltype(df, col_ind), nrow(df))
    for i=1:nrow(df)
        ret[i] = df[i, col_ind]
    end
    return ret
end

function getrows(df::TreeDataFrame, ba::BitArray{1})
    rows = Array(Int64, sum(ba))
    i = 0
    j = 0
    for b in ba
        i += 1
        if !b
            continue
        end
        j += 1
        rows[j] = i
    end
    return rows 
end

function Base.getindex{T <: ColumnIndex}(df::TreeDataFrame, ba::BitArray{1}, col_inds::AbstractVector{T})
    rows = getrows(df, ba)
    return df[rows, col_inds]
end

function Base.getindex{T <: ColumnIndex}(df::TreeDataFrame, ba::BitArray{1}, col_ind::T)
    rows = getrows(df, ba)
    return df[rows, col_ind]
end

function Base.getindex{R <: Integer, T <: ColumnIndex}(
        df::TreeDataFrame,
        row_ind::AbstractVector{R}, 
        col_inds::AbstractVector{T}
    )

    cols = Dict()
    for ci in col_inds
        ct = coltype(df, ci)
        cols[ci] = DataArray(ct, length(row_ind))
    end
    i = 1
    set_branch_status!(df.tree, "*", false)
    reset_cache!(df.tree) 
    for ci in col_inds
        cn = colname(df, ci)
        set_branch_status!(df.tree, "$(cn)*", true)
        add_cache!(df.tree, "$(cn)*")
    end
    for ri::R in row_ind
        CMSSW.getentry!(df.tree, ri)

        #get all the column values
        for ci in col_inds
            cols[ci][i] = df[ri, ci, false]
        end
        i += 1
    end
    ret = DataFrame()
    for ci in col_inds
        ret[colname(df, ci)] = cols[ci]
    end
    return ret
end

function Base.getindex{R <: Real}(df::TreeDataFrame, row_ind::AbstractVector{R}, col_ind::ColumnIndex)
    T = coltype(df, col_ind)
    lenvals = length(row_ind)
    da = Array(T, lenvals)
    nas = BitArray(lenvals)
    i=1
    for ri in row_ind
        x = df[ri, col_ind]
        if !isna(x)
            da[i] = x
            nas[i] = false
        else
            da[i] = DataFrames.baseval(T)
            nas[i] = true
        end
        i += 1
    end
    DataArray(da, nas)
end

function to_df(df::TreeDataFrame)
    return df[1:nrow(df), names(df)]
end

export TreeDataFrame
