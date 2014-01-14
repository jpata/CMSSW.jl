ROOT.jl
=======

A toy experiment interfacing ROOT (http://root.cern.ch) and Julia (http://julialang.org) through FWLite. Note that this is highly experimental, very much WIP and expected to change.

Installation
============

* Requirements: the `cmsrel` command must be available (must have done a proper `source cmsset_default.sh`, only available to members of the CMS collaboration for the time being).

To get the package do

> Pkg.add("https://github.com/jpata/ROOT.jl.git")

followed by

> ./setup.sh;make

Troubleshooting
===============

### Generic help

Please always check and report the version hash of the main code and all the submodules using

> git fetch origin; git log HEAD..origin/master --oneline; git rev-parse HEAD; git submodule status --recursive

If any of the submodule hashes contain a ***+*** in the beginning, you need to run

> git submodule update --recursive

TODO
====

1. Move to BinDeps
2. Move to Clang.jl
3. Separate ROOT6 and CMSSW to separate repositorie,s experiment using Cling.
