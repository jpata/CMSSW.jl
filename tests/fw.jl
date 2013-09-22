using ROOT

#Download the test file 
testfile = joinpath(Pkg.dir(), "ROOT.jl", "dat", "test_edm.root")
isfile(testfile) || download("http://cms.hep.kbfi.ee/~joosep/test_edm.root", testfile)

#Open the events file
ev = Events(testfile)
assert(length(ev) == 297977)

#Define the muon source (this can be done programmatically and shortened/generalized considerably)
sum_pt = 0.0

#Profile.init(10^7, 0.00001)

immutable TagHandle
    tag::InputTag
    handle::Handle
end

const mu_pt = TagHandle(ev.tags[(:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2)]...)
const mu_eta = TagHandle(ev.tags[(:goodSignalMuonsNTupleProducer, :Eta, :STPOLSEL2)]...)

tags = [TagHandle(y...) for (x,y) in ev.tags]

function get(ev::Events, th::TagHandle, copy::Bool=false)
    arr = ev[th.tag, th.handle]
    return (copy ? deepcopy(arr) : arr)
end

#Loop over all the events, do a timing test as well
do_loop(ev::Events) = for i=1:length(ev)

    global sum_pt::Float64
    global mu_pt, mu_eta

    #Move to the i-th event (! means that the parameters are modified in-place, as is the case for Events)
    to!(ev, i)

    mupt::Vector{Float32} = get(ev, mu_pt, false)
    mueta::Vector{Float32} = get(ev, mu_eta, false)

    #Loop over the muons
    for pt in mupt
        sum_pt += pt
    end
    id = where(ev)
    #println("$(id.run):$(id.lumi):$(id.event)")
end

prfile = open("prof.txt", "w")
for i=1:5
    el = @elapsed do_loop(ev)
    println("speed=", length(ev)/el)
end

#Profile.print(prfile, format=:flat, cols=160, C=true)

#Profile.print(C=true)
#println("processed N=$(length(ev)) events, speed=$(length(ev)/el) events/second")
#println("sum_pt = ", sum_pt)
