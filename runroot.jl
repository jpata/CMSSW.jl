require("src/root.jl")
path = "dat/TTJets_FullLept.root:trees/Events"
#ex = :(@everywhere println("Worker=", myid()))
@eval @everywhere println("path=", $(path))

@eval @everywhere tree = Tree($path)
@everywhere construct_type(tree)
@everywhere eval(make_constructor(Event, tree))
@everywhere event = Event(tree)
@everywhere println("Tree = ", string(tree))
#pmap_tree(x->x, tree)


@everywhere read_n(n::Int64) = event.cos_theta[n]
@everywhere (
    function read_range(entries::Range1{Int64})
        #println("Reading range ", entries)
        return map(n -> event.cos_theta[n], entries)
    end
)

chunk(n, c, maxn) = sum([n]*(c-1))+1:min(n*c, maxn)

function par()
    println("Calling parallel loop")
    n = length(tree)
    #split_to = nprocs()
    cn = 10000
    ranges = [chunk(cn, i, n) for i=1:convert(Int64, ceil(n/cn))]
    #println(ranges)
    ref = pmap(
        read_range, ranges
    )
    println("Waiting for loop to finish")
    ret = fetch(ref)
    return reduce(vcat, [], ret)
end

t = @elapsed r = par()
println(sum(r))
println("Processed ", length(tree)/t, " events/second.")
println(length(r))
println(length(tree))