#!/bin/bash

SCRAMEXE=`which scram`
if [ -z "$SCRAMEXE" ]; then
    echo "ERROR: scram not found, did you source cmsset_default.sh?" 1>&2
    exit 1
fi

echo "Julia called through Julia+CMSSW wrapper, exe path="`which julia`

#use system python
PYPATH=$(dirname `which python`)
echo "using python from $PYPATH instead of CMSSW"

#get the absolute path of this script
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#set the CMSSW path
source $scriptdir/setenv.sh && PATH=$PYPATH:$PATH $@
