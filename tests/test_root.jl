require("src/root.jl")
path = "dat/test.root:trees/Events"
tree = Tree(path)
println(string(tree))
for (bn, b) in tree.branches
    println(b)
end