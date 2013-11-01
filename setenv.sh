#get current dir
d=`pwd`

#get script dir
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#set CMSSW environment
cd $scriptdir/deps/ntuple/CMSSW
eval `scram runtime -sh`

#go back
cd $d
