#!/bin/bash
cd src
CMSSW_VERSION=CMSSW_5_3_11_FWLITE
mv $CMSSW_VERSION bak
scram project CMSSW $CMSSW_VERSION 
git checkout $CMSSW_VERSION 
cd ..

