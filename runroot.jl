require("src/root.jl")
#path = "/hdfs/local/stpol/step3/37acf5_343e0a9_Aug22/mu/mc/iso/nominal/Jul15/T_t_ToLeptons.root:trees/Events"
path = "dat/test.root:trees/Events"
#ex = :(@everywhere println("Worker=", myid()))
@eval @everywhere println("path=", $(path))

@eval @everywhere tree = Tree($path)
@everywhere construct_type(tree)
@everywhere eval(make_constructor(Event, tree))
@everywhere event = Event(tree)
@everywhere println("Tree = ", string(tree))

@everywhere begin
    type State
        n_jets::Int64
        accumulator::Float64
    end
end

@everywhere begin  
    function evloop(n::Int64, s::State)

        nj = event.n_jets[n]
        if nj != s.n_jets
            return (n, false)
        end

        cos_theta = event.cos_theta[n]
        if cos_theta>-1.0
            s.accumulator += cos_theta
            return (n, true)
        else
            return (n, false)
        end

    end
    function read_range(entries::Range1{Int64}, rr::RemoteRef)

        #Copy the state from the parent
        state = deepcopy(fetch(rr))
        #println("Got State: ", state)

        ret = map(n -> evloop(n, state), entries)
        return (ret, state)
    end
end

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)

function par(njets)
    println("Calling parallel loop")
    n = length(tree)
    
    cn = 50000
    
    ranges = [
        chunk(cn, i, n) for i=1:convert(Int64, ceil(n/cn))
    ]
    println("Job split to ", length(ranges), " chunks between ", nprocs(), " processes.")
    rr = RemoteRef()
    put(rr, State(njets, 0.0))
    
    ref = pmap(
        n -> read_range(n, rr), ranges
    )
    
    println("Waiting for loop to finish")
    ret = fetch(ref)
    states = [r[2] for r in ret]
    println(states)
    return [r[1] for r in ret]
end

rets = Any[]

for i=1:5
    println("njets = ", i)
    t = @elapsed r = par(i)
    println("Processed ", length(tree)/t, " events/second.")
    push!(rets, r)
    println("Ret size = ", size(r))
    # for _r in r
    #     println(size(_r))
    # end
    passed = map(_r -> count(x -> x[2], _r), r) |> sum 
    failed = map(_r -> count(x -> !x[2], _r), r) |> sum 
    println("passed=", passed, " failed=", failed)
end
