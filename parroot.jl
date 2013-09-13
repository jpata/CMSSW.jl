function init()
    require("src/root.jl")
    @everywhere treepaths = {"hdfs:///local/joosep/test_opt.root:trees/Events"}
    @everywhere begin
        results = Dict{ASCIIString, Dict{Symbol, Any}}()
        trees = Dict{ASCIIString, Tree}()
    
        for t in treepaths
            trees[t] = Tree(t)
            ttree_set_cache(trees[t].tree, 100)
            results[t] = Dict{Symbol, Any}()
            results[t][:cos_theta] = Histogram(10, -1, 1)
        end
    end

    @everywhere function loopfn(n::Integer, tree::Tree)
        global results
    
        cos_theta::Float32 = tree[:cos_theta, n]
        if !( cos_theta > -1.0)
            return false
        end
        fill!(results[string(tree)][:cos_theta], cos_theta)
        return true
    end
end



function run(nprocs)
    println("Mapping over ", nprocs, " jobs")
    n, refs = process_parallel(loopfn, :(trees[treepaths[1]]), nprocs)
    for r in refs
        wait(r)
    end
    return n
end

addprocs(10)
np = nprocs()
init()

times = Any[]
for np=1:10
    el = @elapsed n=run(np)
    push!(times, (np, n, el, n/el))
end
for t in times
    println(t)
end
