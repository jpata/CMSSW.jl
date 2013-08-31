require("src/root.jl")
path = "/hdfs/local/stpol/step3/37acf5_343e0a9_Aug22/mu/mc/iso/nominal/Jul15/T_t_ToLeptons.root:trees/Events"
#path = "dat/test.root:trees/Events"
#ex = :(@everywhere println("Worker=", myid()))
@eval @everywhere println("path=", $(path))

@eval @everywhere tree = Tree($path)
@everywhere construct_type(tree)
@everywhere eval(make_constructor(Event, tree))
@everywhere event = Event(tree)
@everywhere println("Tree = ", string(tree))

@everywhere begin

    immutable State
        accumulator::Float64
        cut_n_jets::Int64
    end
    
    function evloop(n::Int64, s::State)

        nj = event.n_jets[n]
        if nj!=s.cut_n_jets
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
    function read_range(entries::Range1{Int64}, _s::State)
        s = State(0.0, _s.cut_n_jets)
        return (map(n -> evloop(n, s), entries), s)
    end
end

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)

function par(njets)
    println("Calling parallel loop")
    n = length(tree)
    
    cn = 100000
    
    ranges = [
        chunk(cn, i, n) for i=1:convert(Int64, ceil(n/cn))
    ]
    
    @everywhere accumulator = 0.0
    @eval @everywhere njets = $njets
    
    s = State(0.0, njets)

    ref = pmap(
        r -> read_range(r, s), ranges
    )
    
    println("Waiting for loop to finish")
    ret = fetch(ref)
    println("Fetching accumulator")
    tot_acc = fetch(@spawn accumulator)
    println("tot_acc=", tot_acc) 
    println("Performing reduce")
    return ret
end

rets = Any[]

for i=1:5
    println("njets = ", i)
    t = @elapsed r = par(i)
    println("Processed ", length(tree)/t, " events/second.")
    push!(rets, r) 
    passed = map(_r -> count(x -> x[2], _r), r) |> sum 
    failed = map(_r -> count(x -> !x[2], _r), r) |> sum 
    println("passed=", passed, " failed=", failed)
end
