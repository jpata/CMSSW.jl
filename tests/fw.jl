using ROOT

#Download the test file 
testfile = joinpath(Pkg.dir(), "ROOT.jl", "dat", "test_edm.root")
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_edm.root", testfile)

#Open the events file
ev = Events(testfile)
assert(length(ev) == 297977)

muon_pts = Float32[]

#Define the muon source (this can be done programmatically and shortened/generalized considerably)
mu_pts(ev::Events) = ev[:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2]

#Loop over all the events, do a timing test as well
el = @elapsed for i=1:length(ev)

    #Move to the i-th event (! means that the parameters are modified in-place, as is the case for Events)
    to!(ev, i)

    #Loop over the muons
    for pt in mu_pts(ev)
        push!(muon_pts, pt)
    end
end

println("processed N=$(length(ev)) events, speed=$(length(ev)/el) events/second")

assert(abs(sum(muon_pts) - 2.4204095e6) < 1.0)

#println("pts: ", join(muon_pts[1:3], ", "))
println("sum_pt = ", sum(muon_pts))
