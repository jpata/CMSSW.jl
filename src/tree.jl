ccall((:hello, "libtree.dylib"), Void, ())

#t = ccall((:new_TTree, "libtree.dylib"), Ptr{Void}, (Ptr{Uint8},), "blarg")

tf = ccall((:open_TFile, "libtree.dylib"), Ptr{Void}, (Ptr{Uint8},), "data/Jul26/83a02e9_Jul22/mu/data/iso/Jul15/SingleMu3.root")

println("Opened TFile: ", tf)
ttree = ccall((:TFile_get, "libtree.dylib"), Ptr{Void}, (Ptr{Void}, Ptr{Uint8}),
    tf,
    "trees/Events"
)

println("Opened TTree: ", ttree)
nentries = ccall((:TTree_get_n_entries, "libtree.dylib"), Int64, (Ptr{Void},), ttree)

println("Entries in TTree: ", nentries)

n_jets = Array(Cint, 1)
bradd = ccall((:TTree_set_branch_address, "libtree.dylib"), Cint, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), ttree,
    "n_jets",
    n_jets
)

cos_theta = Array(Cfloat, 1)
bradd = ccall((:TTree_set_branch_address, "libtree.dylib"), Cint, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), ttree,
    "cos_theta",
    cos_theta
)


ccall((:TTree_set_branch_status, "libtree.dylib"), Void, (Ptr{Void}, Ptr{Uint8}, Bool), ttree,
    "*",
    false
)

ccall((:TTree_set_branch_status, "libtree.dylib"), Void, (Ptr{Void}, Ptr{Uint8}, Bool), ttree,
    "n_jets",
    true
)

ccall((:TTree_set_branch_status, "libtree.dylib"), Void, (Ptr{Void}, Ptr{Uint8}, Bool), ttree,
    "cos_theta",
    true
)

ngot = 0
ntot = nentries
arr = Array((Int32, Float32), ntot)
for i in 1:ntot
    ngot += ccall((:TTree_get_entry, "libtree.dylib"), Cint, (Ptr{Void}, Clong), ttree, i)
    arr[i] = (n_jets[1], cos_theta[1])
end
println("Got ", ngot/1024/1024, " MB")
