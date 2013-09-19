fwtree:
	cd src/CMSSW*; scram b
	cd ..
	cp src/CMSSW_5_3_11_FWLITE/lib/$(SCRAM_ARCH)/libFWTree.dylib lib/
	# c++ -shared -fPIC `root-config --cflags --ldflags --libs` src/tree.cpp -o lib/libtree.dylib

class:
	clang++ src/class.cc -fPIC -shared -o libclass.dylib

tree:
	mkdir -p lib
	c++ src/root.cc `root-config --libs --ldflags --cflags` -fPIC -shared -o lib/libroot.dylib

all: tree, fwtree

simple:
	c++ src/simple.cc `root-config --libs --ldflags --cflags` -shared -fPIC -o simple


