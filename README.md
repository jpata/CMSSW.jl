ROOT.jl
=======

A toy experiment interfacing ROOT (http://root.cern.ch) and Julia (http://julialang.org) through FWLite. Note that this is highly experimental, very much WIP and expected to change.

Julia is a quickly-evolving language for technical computing which executes at near-C speeds on LLVM. ROOT is a data analysis library widely used at experiments at CERN for HEP data analyses. Traditionally, ROOT is accessed through the C++ interface, however many analysis tasks can be more succintly expressed and evaluated in a more high level language. Julia provides the much of the flexibility of Python with much of the speed of bare-metal C.

Presently, this library is used throughout at least one CMS analysis.

----

Currently, access to so-called ``EDM-Ntuples`` containing basic types like double, float, int and the corresponding vectors is supported and tested.

Additionally, this library supports basic access methods for ROOT TTree and TFile types, in particular conversion between Julia DataFrames and ROOT TTrees.

Further features could be added, but at the moment, this requires manually creating C wrappers for each function using opaque pointers, which can become unwieldy. Therefore, only the most essential ROOT methods are wrapped at the moment.

Installation
============

* Requirements: the `cmsrel` command must be available (must have done a proper `source cmsset_default.sh`, only available to members of the CMS collaboration for the time being).

To get the package first install Julia, preferrably from the git trunk (see http://julialang.org)

Then add this package to your Julia package database

> Pkg.add("https://github.com/jpata/ROOT.jl.git")
> Pkg.add("DataFrames") #dependencies
> Pkg.add("DataArrays") #dependencies

followed by

> ./setup.sh;make


Usage
=====

Julia can be called with the proper libraries by using

> ~/.julia/ROOT/julia

	Darwin pata-macbook-3.local 13.0.0 Darwin Kernel Version 13.0.0: Thu Sep 19 22:22:27 PDT 2013; root:xnu-2422.1.72~6/RELEASE_X86_64 x86_64
	Julia called through Julia+CMSSW wrapper, exe path=/Users/joosep/Documents/julia/julia
	using python from /usr/bin instead of CMSSW
	               _
	   _       _ _(_)_     |  A fresh approach to technical computing
	  (_)     | (_) (_)    |  Documentation: http://docs.julialang.org
	   _ _   _| |_  __ _   |  Type "help()" to list help topics
	  | | | | | | |/ _` |  |
	  | | |_| | | | (_| |  |  Version 0.3.0-prerelease+1364 (2014-02-02 19:54 UTC)
	 _/ |\__'_|_|_|\__'_|  |  Commit 2320f42* (2 days old master)
	|__/                   |  x86_64-apple-darwin13.0.0

	julia> using ROOT
	ROOT+FWLite initialized: 5.34/01

	julia> events = Events("dat/test_edm.root")
	julia> for i=1:length(ev)
	       		to!(ev, i)
	       		pts = ev[s]
	       		length(pts)>0 && println(
	       			"$i pt=", join(pts, ",")
	       		)
	       end
       2 pt=51.711132
       7 pt=38.312836
       9 pt=39.892628
       10 pt=28.58129
       17 pt=42.227287
       18 pt=44.519432
       32 pt=55.485973
       35 pt=39.675224
       38 pt=28.06808
       42 pt=37.52404
       47 pt=53.73965
       51 pt=30.006735
       61 pt=89.722855
       62 pt=52.477253
       68 pt=79.75265
       96 pt=29.263891
       97 pt=45.09394

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
3. Separate ROOT6 and CMSSW to separate repositories experiment using Cling.
