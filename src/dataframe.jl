using ROOT
using DataFrames
import DataFrames.nrow, DataFrames.colnames
import Base.getindex, Base.display

typealias ColumnIndex Union(Real, String, Symbol)

type TreeDataFrame <: AbstractDataFrame
    file::ROOT.TFile
    tree::ROOT.TTree
end

function TreeDataFrame(fn::ASCIIString)
    file = ROOT.TFile(fn, "READ")
    tree = ROOT.TTree(file, "dataframe")
    return TreeDataFrame(file, tree)
end

DataFrames.nrow(df::TreeDataFrame) = length(df.tree)
DataFrames.colnames(df::TreeDataFrame) = df.tree.colnames

function colname(df::TreeDataFrame, col_ind::ColumnIndex)
    if typeof(col_ind) <: Real
        cn = colnames(df)[col_ind]
    else
        cn = string(col_ind)
    end
    return cn
end

function coltype(df::TreeDataFrame, col_ind::ColumnIndex)
    ci = find(x -> x == colname(df, col_ind), colnames(df))
    length(ci) == 1 ? df.tree.coltypes[ci[1]] : error("undefined column: $col_ind")
end

function Base.getindex(df::TreeDataFrame, row_ind::Real, col_ind::ColumnIndex)
    ROOT.getentry!(df.tree, row_ind)
    cn = colname(df, col_ind)
    return df.tree[cn]
end

Base.display(df::TreeDataFrame) = show(df.tree.colnames)

function Base.getindex{T <: ColumnIndex}(df::TreeDataFrame, row_ind::Real, col_inds::AbstractVector{T})
    DataFrame({colname(df, ci) => df[row_ind, ci] for ci in col_inds})
end

function Base.getindex{R <: Real, T <: ColumnIndex}(df::TreeDataFrame, row_ind::AbstractVector{R}, col_inds::AbstractVector{T})
    DataFrame({colname(df, ci) => [df[ri, ci] for ri in row_ind] for ci in col_inds})
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
#df = TreeDataFrame("/Users/joosep/Documents/stpol/data/test.root")
#x = df[10, ["met", "mtw", "sjet2_pt"]]
