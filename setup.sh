#!/bin/bash
cd src
CMSSW_VERSION=CMSSW_5_3_11
mv $CMSSW_VERSION bak
scram project  -n CMSSW CMSSW $CMSSW_VERSION 
git checkout $CMSSW_VERSION 
cd ..

