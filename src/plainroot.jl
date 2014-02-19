const libplainroot = joinpath(ENV["CMSSW_BASE"], "lib", ENV["SCRAM_ARCH"], "libplainroot")
#const libplainroot = joinpath("deps/ntuple/", "libplainroot_jl")

using DataArrays, DataFrames
import DataArrays.NAtype
import Base.close

typealias ColumnIndex Union(Real, String, Symbol)

import Base.Test
import Base.get, Base.cd, Base.mkdir, Base.write, Base.close, Base.fill, Base.mkpath

const plain_type_table = {
    "Float_t"=>Float32,
    "Double_t"=>Float64,
    "Int_t"=>Int32,
    "Long64_t"=>Int64,
    "ULong64_t"=>Uint64,
    "Char_t"=>ASCIIString,
    "Bool_t"=>Bool
}

#A C struct for a variable size array
immutable CArray
    start::Ptr{Ptr{Void}} #Pointer to the start of the array
    size::Cint #Size of an element in the array
    n_elems::Cint #Length of the array
end

#generic TObject::Write, will work for TFile, TH1D, TTree, etc...
Base.write(x::Ptr{Void}) = ccall(
    (:tobject_write, libplainroot),
    Void, (Ptr{Void}, ), x
)

#short type names used in ROOT's TBranch constructor for the leaflist
const typemap = {
    Float32 => "F",
    Float64 => "D",
    Int32 => "I",
    Int64 => "L",
    Uint64 => "l",
#    ASCIIString => "C",
    Uint8 => "C",
    Bool => "O"
}

include("deprecated.jl")
include("tfile.jl")
include("ttree.jl")
include("hist.jl")
include("tmva.jl")

export close
export writetree, readtree, ColumnIndex, coltype
export set_branch_status!, reset_cache!, add_cache!
export new_th1d, new_th2d, TFile
