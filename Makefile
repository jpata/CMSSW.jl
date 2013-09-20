#fwtree:
#	echo "Making FWtree";
#	mkdir -p lib
#	cd src/CMSSW; scram b vclean; scram b
#	#cd ..
#	rm -f lib/libFWTree*
#	cp src/CMSSW/lib/$(SCRAM_ARCH)/libFWTree.* lib/
#
#tree: src/root.cc
#	echo "Making tree";
#	mkdir -p lib
#	rm -f lib/libroot*
#	c++ src/root.cc `root-config --libs --ldflags --cflags` -O4 -fPIC -shared -o lib/libroot.dylib
#	ln -s lib/libroot.dylib lib/libroot.so

all:
	cd src/CMSSW; scram b vclean; scram b -k || scram b; scram b	
	cd ../..

setup:
	./setup.sh


c_test:
	time src/CMSSW/bin/$(SCRAM_ARCH)/simple

jl_test:
	time julia tests/fw.jl

test: c_test jl_test

clean:
	rm lib/*

#simple:
#	c++ src/simple.cc -std=c++0x `root-config --libs --ldflags --cflags` -I$(CMSSW_RELEASE_BASE)/src/ -Lsrc/CMSSW/lib/$(SCRAM_ARCH)/ -lfwlevents_c -lboost_rt -fPIC -o simple


