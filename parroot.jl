require("src/root.jl")

@everywhere begin
    tree = Tree("dat/test.root:trees/Events")
    event = Event(tree)
    entries = Any[]
    sum_pt = 0.0

    hist = Histogram(10, -1, 1)
end

maxn = length(tree)/10
el = @elapsed pl = @parloop 10000 for event_number=1:maxn
    global sum_pt::Float64
    global hist::Histogram

    event.tree.index = event_number

    event_id::Int32 = @get event :event_id
    cos_theta::Float32 = @get event :cos_theta
    mu_pt::Float32 = @get event :mu_pt
    pu_weight = @get event :pu_weight
    fill(hist, cos_theta, pu_weight)
    sum_pt += mu_pt
    #push!(entries, event_id)
    #println(event_id, " ", cos_theta)
    return true
end
ntot = map(fetch, pl) |> sum
#assert(ntot==maxn, "Wrong number of events processed")
#println(ret)

#reduce
rets = Any[]
for i=1:nprocs()
    ret = remotecall_fetch(i, ()->(sum_pt, hist))
    push!(rets, ret)
end
for r in rets
    println(r)
end
println("Processed ", ntot/el, " events/second")