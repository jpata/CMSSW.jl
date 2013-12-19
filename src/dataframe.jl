using ROOT
using DataFrames
import DataFrames.nrow, DataFrames.ncol, DataFrames.colnames
import Base.getindex, Base.setindex!, Base.display

type TreeDataFrame <: AbstractDataFrame
    file::ROOT.TFile
    tree::ROOT.TTree
    ramdf::DataFrame
end

function TreeDataFrame(fn::ASCIIString)
    file = ROOT.TFile(fn, "READ")
    tree = ROOT.TTree(file, "dataframe")
    ramdf = DataFrame()
    return TreeDataFrame(file, tree, ramdf)
end

TreeDataFrame(df::TreeDataFrame) = TreeDataFrame(df.file.s)

DataFrames.nrow(df::TreeDataFrame) = length(df.tree)
DataFrames.ncol(df::TreeDataFrame) = length(df.tree.colnames)
DataFrames.colnames(df::TreeDataFrame) = vcat(df.tree.colnames, colnames(df.ramdf))

function colname{T <: Integer}(df::TreeDataFrame, col_ind::T)
    return colnames(df)[col_ind]
end

function colname{T <: ColumnIndex}(df::TreeDataFrame, col_ind::T)
    return string(col_ind) 
end

function coltype(df::TreeDataFrame, col_ind::ColumnIndex)
    ci = find(x -> x == colname(df, col_ind), colnames(df))
    if length(ci) == 1
        ci[1] <= length(df.tree.coltypes) ? df.tree.coltypes[ci[1]] : Any
    else
        warn("undefined column type for $col_ind")
        return Any
    end
end

function Base.setindex!{R <: Real}(df::TreeDataFrame, val::R, col_ind::ColumnIndex)
    if nrow(df.ramdf)==0
        df.ramdf[col_ind] = DataArray(val, nrow(df))
    else
        df.ramdf[col_ind] = val
    end
end

function Base.setindex!{R <: Real, K <: Number}(
    df::TreeDataFrame,
    val::R,
    row_ind::AbstractVector{K},
    col_ind::ColumnIndex
    )

    df.ramdf[row_ind, col_ind] = val
end

function Base.setindex!{R <: Real, K <: Number}(
    df::TreeDataFrame,
    vals::AbstractVector{R},
    row_ind::AbstractVector{K},
    col_ind::ColumnIndex
    )
    
    df.ramdf[row_ind, col_ind] = vals
end

function Base.setindex!{R <: Real}(
    df::TreeDataFrame,
    vals::AbstractVector{R},
    col_ind::ColumnIndex
    )
    df.ramdf[col_ind] = vals
end


function Base.getindex{R <: Real}(df::TreeDataFrame, row_ind::R, col_ind::ColumnIndex, doget=true)
    
    #prefer the column in RAM
    if string(col_ind) in colnames(df.ramdf)
        return df.ramdf[row_ind, col_ind]
    else
        doget && ROOT.getentry!(df.tree, row_ind)
        cn = colname(df, col_ind)
        return df.tree[cn]
    end
end

Base.display(df::TreeDataFrame) = show(df.tree.colnames)

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

function Base.getindex{R <: Real, T <: ColumnIndex}(
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
    for ri in row_ind
        #do ROOT::TTree::GetEntry(ri) with an arbitrary column
        #df[ri, col_inds[1], true]
        ROOT.getentry!(df.tree, ri)

        #get all the column values
        for ci in col_inds
            cols[ci][i] = df[ri, ci, false]
        end
        i += 1
    end
    DataFrame({colname(df, ci) => cols[ci] for ci in col_inds})
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
    return df[1:nrow(df), colnames(df)]
end

export TreeDataFrame
