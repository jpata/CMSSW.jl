using ROOT

#Download the test file 
testfile = joinpath(Pkg.dir(), "ROOT.jl", "dat", "test_edm.root")
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_edm.root", testfile)

#Open the events file
ev = Events(testfile)
assert(length(ev) == 297977)

sum_pt = 0.0

const mu_pt = Source(
    InputTag(:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2), Handle(Vector{Cfloat})
)
const mu_eta = Source(
    InputTag(:goodSignalMuonsNTupleProducer, :Eta, :STPOLSEL2), Handle(Vector{Cfloat})
)

#Loop over all the events, do a timing test as well
function do_loop(ev::Events)
    
    global sum_pt
    sum_pt = 0.0

    #global mu_pt, mu_eta

    for i=1:length(ev)

        #Move to the i-th event (! means that the parameters are modified in-place, as is the case for Events)
        to!(ev, i)

        mupt::Vector{Float32} = ev[mu_pt]
        mueta::Vector{Float32} = ev[mu_eta]

        #Loop over the muons
        for (pt, eta) in zip(mupt, mueta)
            sum_pt += pt
        end

        #run, lumi, event
        id = where(ev)
    end
end

for i=1:5
    el = @elapsed do_loop(ev)
    println("speed=", length(ev)/el)
end

println("sum_pt = ", sum_pt)
