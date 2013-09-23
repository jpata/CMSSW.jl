d=`pwd`

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir/src/CMSSW
eval `scram runtime -sh`
cd $d
