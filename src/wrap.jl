using Clang
clang_extraargs = ["-v"]
clang_includes = convert(Array{ASCIIString, 1}, [])
const wc = wrap_c.WrapContext(
    "./", "fwlite_common.jl", clang_includes,
    clang_extraargs,
    x -> True,
    x -> "libFWLite.dylib",
    x -> "fwlite.jl"
)

wrap_c.wrap_c_headers(wc, ["src/CMSSW_5_3_11_FWLITE/src/SingleTopPolarization/libtree/bin/libFWTree.cpp"])