all:
	cd deps/ntuple; make clean; make lib;

setup:
	./setup.sh

jl_test:
	time julia tests/fw.jl

test: jl_test
