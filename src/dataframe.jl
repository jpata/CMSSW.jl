using ROOT
using DataFrames
import DataFrames.nrow, DataFrames.colnames
import Base.getindex, Base.display

type TreeDataFrame <: AbstractDataFrame
    file::ROOT.TFile
    tree::ROOT.TTree
end

function TreeDataFrame(fn::ASCIIString)
    file = ROOT.TFile(fn, "READ")
    tree = ROOT.TTree(file, "dataframe")
    return TreeDataFrame(file, tree)
end

TreeDataFrame(df::TreeDataFrame) = TreeDataFrame(df.file.s)

DataFrames.nrow(df::TreeDataFrame) = length(df.tree)
DataFrames.colnames(df::TreeDataFrame) = df.tree.colnames

function colname{T <: Integer}(df::TreeDataFrame, col_ind::T)
    return colnames(df)[col_ind]::ASCIIString
end

function colname{T <: ColumnIndex}(df::TreeDataFrame, col_ind::T)
    return string(col_ind) 
end

function coltype(df::TreeDataFrame, col_ind::ColumnIndex)
    ci = find(x -> x == colname(df, col_ind), colnames(df))
    length(ci) == 1 ? df.tree.coltypes[ci[1]] : error("undefined column: $col_ind")
end

function Base.getindex{R <: Real}(df::TreeDataFrame, row_ind::R, col_ind::ColumnIndex, doget=true)
    doget && ROOT.getentry!(df.tree, row_ind)
    cn = colname(df, col_ind)
    return df.tree[cn]
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
    df::TreeDataFrame, row_ind::AbstractVector{R}, 
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
        df[ri, col_inds[1], true]

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
