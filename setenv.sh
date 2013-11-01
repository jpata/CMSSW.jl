d=`pwd`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir/deps/ntuple/CMSSW
eval `scram runtime -sh`
cd $d
#
#export INCLUDE_DIR=$scriptdir/..
