d=`pwd`

DISTR=`python -c "import platform; print (platform.system() + ' ' + ' '.join(platform.linux_distribution()))"`

if [[ "$DISTR" == *Darwin* ]]
then
    echo "OSX detected";
    export SCRAM_ARCH=osx107_amd64_gcc462
fi
if [[ "$DISTR" == *"Scientific Linux 6"* ]]
then
    echo "SL6 detected";
    export SCRAM_ARCH=slc6_amd64_gcc472
fi
if [[ "$DISTR" == *"Scientific Linux 5"* ]]
then
    echo "SL5 detected";
    export SCRAM_ARCH=slc5_amd64_gcc462
fi


scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir/src/CMSSW
eval `scram runtime -sh`
cd $d

export INCLUDE_DIR=$scriptdir/..
