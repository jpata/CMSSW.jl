using ROOT

testfile = joinpath(Pkg.dir(), "ROOT.jl", "dat", "test_edm.root")

show(testfile)

println()
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_edm.root", testfile)

ev = Events(testfile)
assert(length(ev) == 297977)

muon_pts = Float32[]
el = @elapsed for i=1:length(ev)
    to!(ev, i)

    for pt in ev[:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2]
        push!(muon_pts, pt)
    end
end
println("processing speed: $(length(ev)/el) events/second")

assert(abs(sum(muon_pts) - 2.4204095e6) < 1.0)
println("pts: ", join(muon_pts[1:3], ", "))
