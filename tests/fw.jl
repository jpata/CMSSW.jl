tic()
using ROOT
using DataFrames

using Base.Test

#Download the test file 
testfile = joinpath(Pkg.dir(), "ROOT", "dat", "test_edm.root")
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_100ev.root", testfile)

#Open the events file
ev = Events(testfile)
@test length(ev) == 100

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

const cos_theta = Source(
    InputTag(:cosTheta, :cosThetaLightJet, :STPOLSEL2), Handle(Float64)
)

const n_jets = Source(
    InputTag(:goodJetCount, symbol(""), :STPOLSEL2), Handle(Int32)
)

const n_tags = Source(
    InputTag(:bJetCount, symbol(""), :STPOLSEL2), Handle(Int32)
)

const hlts = ASCIIString[
    "HLT_IsoMu24_eta2p1_v11",
    "HLT_IsoMu24_eta2p1_v12",
    "HLT_IsoMu24_eta2p1_v13",
    "HLT_IsoMu24_eta2p1_v14",
    "HLT_IsoMu24_eta2p1_v15",
    "HLT_IsoMu24_eta2p1_v17",
    "HLT_IsoMu24_eta2p1_v16",
    "HLT_Ele27_WP80_v8",
    "HLT_Ele27_WP80_v9",
    "HLT_Ele27_WP80_v10",
    "HLT_Ele27_WP80_v11",
]

cos_thetas = Any[]
pass_hlts = 0
sum_pt = 0.0
sum_jets = 0

ids = Any[]
for i=1:length(ev)

    #Move to the i-th event (! means that the parameters are modified in-place, as is the case for Events)
    to!(ev, i)

    mupt::Vector{Float32} = ev[mu_pt]
    mueta::Vector{Float32} = ev[mu_eta]

    ct = ev[cos_theta]
    push!(cos_thetas, ct)

    nj = ev[n_jets]
    sum_jets += (!isna(nj) ? nj : 0)

    nt = ev[n_tags]
    #println("$nj, $nt, $ct")

    #Loop over the muons
    for (pt, eta) in zip(mupt, mueta)
        sum_pt += pt
    end

    #run, lumi, event
    id = where(ev)
    
    idx = where_file(ev)
    
    fname = get_current_file_name(ev)
    println(fname)

    push!(ids, id)

    hlt = passes_hlt(ev, hlts)
    pass_hlts += hlt ? 1 : 0

end

toc()

@test_approx_eq_eps abs(sum_pt) 786.054895401001 1.0
@test sum([isna(c) for c in cos_thetas])==84
@test pass_hlts == 39
@test sum_jets == 49

println("Tests conducted successfully")
