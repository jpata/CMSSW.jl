addprocs(3)

require("src/root.jl")
@everywhere trees = {"file://dat/test.root:trees/Events"}
@everywhere begin
    
    results = Dict()
    for t in trees
        results[string(t)] = Dict()
        results[string(t)][:cos_theta] = Histogram(10, -1, 1)
    end
end

@everywhere function loopfn(n::Integer, tree::Tree)
    global results

    cos_theta::Float32 = tree[:cos_theta, n]
    fill!(results[string(tree)][:cos_theta], cos_theta)
    return true
end


function run(nprocs)
    n, refs = process_parallel(loopfn, "file://dat/test.root:trees/Events")
    for r in refs
        wait(r)
    end
    @everywhere tfile_close(local_tree.file)
    return n
end

