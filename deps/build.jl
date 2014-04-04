using BinDeps
@BinDeps.setup

(haskey(ENV, "VO_CMS_SW_DIR") && haskey(ENV, "SCRAM_ARCH")) ||
    error("could not find CMSSW, make sure you have set SCRAM_ARCH and ran `source cmsset.sh`")

cd(joinpath(dirname(Base.source_path()), ".."))

@linux_only run(`make`)
@osx_only run(`make`)
@windows_only error("windows not yet supported, tested, try `make`")
