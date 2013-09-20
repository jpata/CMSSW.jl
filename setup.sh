#!/bin/bash
cd src
CMSSW_VERSION=CMSSW_5_3_11
scram project  -n CMSSW CMSSW $CMSSW_VERSION 
git checkout CMSSW
cd ..

