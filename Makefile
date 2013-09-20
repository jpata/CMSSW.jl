fwtree:
	echo "Making FWtree";
	mkdir -p lib
	cd src/CMSSW; scram b vclean; scram b
	#cd ..
	cp src/CMSSW/lib/$(SCRAM_ARCH)/libFWTree.* lib/

tree: src/root.cc
	echo "Making tree";
	mkdir -p lib
	c++ src/root.cc `root-config --libs --ldflags --cflags` -fPIC -shared -o lib/libroot.so

all: tree fwtree

simple:
	c++ src/simple.cc `root-config --libs --ldflags --cflags` -shared -fPIC -o simple

class:
	clang++ src/class.cc -fPIC -shared -o libclass.dylib


