#!/bin/bash
mkdir -p dat
git submodule init
git submodule update
cd deps/ntuple
./setup.sh
