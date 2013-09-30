println("Running with workers=[", join(workers(), ","), "], controller=$(myid())")

@everywhere begin

    using ROOT

    treepaths = {
        "file://dat/test_edm.root"
    }

    events = Events(treepaths)

    evid_type = (Int64, Int64, Int64)
    type Results
        nevents::Int64
    end
    Results() = Results(0)
    +(r1::Results, r2::Results) = Results(r1.nevents+r2.nevents, vcat(r1.processed, r2.processed))

    const mu_pt = Source(
        InputTag(:goodSignalMuonsNTupleProducer, :Pt, :STPOLSEL2),
        Handle(Vector{Cfloat})
    )

    const mu_eta = Source(
        InputTag(:goodSignalMuonsNTupleProducer, :Eta, :STPOLSEL2),
        Handle(Vector{Cfloat})
    )

    function loopfn(n::Integer, events::Events, results_symbol::Symbol) 
        results::Results = eval(Main, results_symbol)
        to!(events, n)
        pts = events[mu_pt]
        etas = events[mu_eta]

        results.nevents += 1

        return true
    end
end



function run()
    @onworkers workers() results = Results()
    n, refs = process_parallel(loopfn, :events, workers(), :results)
    
    for r in refs
        wait(r)
    end
    _results = [@fetchfrom w eval(Main, :results) for w in workers()]
    #println(intersect([r.processed for r in _results]))
    println(sum([r.nevents for r in _results]))
    return n
end

el = @elapsed n=run()
println("n=$n, el=$el, speed=$(n/el), wspeed=$(n/el/length(workers()))")
el = @elapsed n=run()
