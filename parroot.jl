println("Running with ", nprocs(), " processes.")
function init()
    #@everywhere treepaths = {"hdfs:///local/joosep/test_opt.root:trees/Events"}
    @everywhere treepaths = {
        "file://dat/test.root:trees/Events",
        "file://../stpol/data/37acf5_343e0a9_Aug22/T_t_ToLeptons.root:trees/Events",
        "file://../stpol/data/37acf5_343e0a9_Aug22/Tbar_t_ToLeptons.root:trees/Events"
    }
    @everywhere begin
        local_results = Results(Histogram(10, -1, 1))
        #results = Dict{ASCIIString, Dict{Symbol, Any}}()
        trees = Dict{ASCIIString, Tree}()
    
        for t in treepaths
            trees[t] = Tree(t)
            ttree_set_cache(trees[t].tree, 0, 100)
        end
    end

    @everywhere function loopfn(n::Integer, tree::Tree, results_symbol::Symbol) 
        results = eval(results_symbol)
        cos_theta::Float32 = tree[:cos_theta, n]
        #cos_theta = 1.0
        if !( cos_theta > -1.0)
            return false
        end
        fill!(results.hist1, cos_theta)
        return true
    end
end



function run(nprocs)
    println("Mapping over ", nprocs, " jobs")
    n = 0
    @everywhere local_results = Results(Histogram(10, -1, 1))

    refs = RemoteRef[]
    for tp in treepaths
        _n, _refs = process_parallel(loopfn, :(trees[$tp]), nprocs, :local_results)
        n += _n
        append!(refs, _refs)
    end
    for r in refs
        wait(r)
    end
    return n
end

require("src/root.jl")
@everywhere begin
    immutable Results
        hist1::Histogram
    end
end

function +(r1::Results, r2::Results)
    r = Results(r1.hist1 + r2.hist1)
    return r
end

np = nprocs()
init()

times = Any[]
for np=1:nprocs()
    el = @elapsed n=run(np)
    #rets = fetch()

    results = sum([@fetchfrom p eval(:local_results) for p=1:np])

    println(results)
    push!(times, (np, n, el, n/el/np))
end

for t in times
    println(t)
end
