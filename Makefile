fwtree:
	mkdir -p lib
	cd src/CMSSW*; scram b
	#cd ..
	cp src/CMSSW_5_3_11_FWLITE/lib/$(SCRAM_ARCH)/libFWTree.dylib lib/

tree: src/root.cc
	mkdir -p lib
	c++ src/root.cc `root-config --libs --ldflags --cflags` -fPIC -shared -o lib/libroot.dylib

all: tree, fwtree

simple:
	c++ src/simple.cc `root-config --libs --ldflags --cflags` -shared -fPIC -o simple

class:
	clang++ src/class.cc -fPIC -shared -o libclass.dylib


