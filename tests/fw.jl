using ROOT

using Base.Test

#Download the test file 
testfile = joinpath(Pkg.dir(), "ROOT.jl", "dat", "test_edm.root")
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_edm.root", testfile)

#Open the events file
ev = Events(testfile)
@test length(ev) == 297977

sum_pt = 0.0

const mu_pt = Source(
    InputTag(:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2), Handle(Vector{Cfloat})
)

for i=1:2
    @test begin
        to!(ev, 97)
        return abs(ev[mu_pt][1] - 45.09394)<1.0
    end
end

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

el = @elapsed do_loop(ev)
@test abs(sum_pt - 2.420409521118164e6) < 1.0