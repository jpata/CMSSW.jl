fwtree:
	echo "Making FWtree";
	mkdir -p lib
	cd src/CMSSW; scram b vclean; scram b
	#cd ..
	rm -f lib/libFWTree*
	cp src/CMSSW/lib/$(SCRAM_ARCH)/libFWTree.* lib/

tree: src/root.cc
	echo "Making tree";
	mkdir -p lib
	rm -f lib/libroot*
	c++ src/root.cc `root-config --libs --ldflags --cflags` -O4 -fPIC -shared -o lib/libroot.dylib
	ln -s lib/libroot.dylib lib/libroot.so

all: tree fwtree

simple:
	c++ src/simple.cc `root-config --libs --ldflags --cflags` -shared -fPIC -o simple

class:
	clang++ src/class.cc -fPIC -shared -o libclass.dylib


