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


