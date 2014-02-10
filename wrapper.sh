#!/bin/bash

echo "Julia called through Julia+CMSSW wrapper, julia exe path="`which julia`

if [ ! -z "$ROOTSYS" ]; then
    echo "ROOTSYS=$ROOTSYS already defined, exiting"
    exit 1
fi

SCRAMEXE=`which scram`
if [ -z "$SCRAMEXE" ]; then
    echo "ERROR: scram not found, did you source cmsset_default.sh?" 1>&2
    exit 1
fi

#use system python
PYPATH=$(dirname `which python`)
echo "using python from $PYPATH instead of CMSSW"

#get the absolute path of this script
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export JULIA_PATH=$( dirname `which julia` )
#set the CMSSW path
source $scriptdir/setenv.sh && PATH=$PYPATH:$PATH $JULIA_PATH/usr/bin/$@
