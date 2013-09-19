# macro mymacro(val, func)
#     :($func($val))
# end

x = :bar
ex = :(
    function foo($x)
        println("Working on ", $x)
        return $x^2
    end
)

@eval @everywhere eval($ex)

chunks = [1:2,3:4,5:6,7:8,9:10]
np = 1
refs = RemoteRef[]
for c in chunks

    rr = remotecall(
        mod1(np, nprocs()),
        _c -> map(foo, _c), c
    )
    np += 1
    push!(refs, rr)
end
println(map(fetch, refs))