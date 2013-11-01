ROOT.jl
=======

A toy experiment interfacing ROOT (http://root.cern.ch) and Julia (http://julialang.org) through FWLite

Installation
============

* Requirements: the `cmsrel` command must be available (must have done a proper `source cmsset_default.sh`)

To get the package do

> Pkg.add("https://github.com/jpata/ROOT.jl.git")

followed by

> ./setup.sh;make


TODO
====

1. Move to BinDeps
2. Move to Clang.jl