all:
	cd deps/ntuple; make;

setup:
	./setup.sh

jl_test:
	time julia tests/fw.jl

test: jl_test
