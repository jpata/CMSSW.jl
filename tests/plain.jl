using ROOT
using DataFrames
using Base.Test

df = DataFrame(
    x=DataVector[1.0,2.0,NA],
    y=DataVector["asd", "bsd", "xyz"],
    z=DataVector[4,5.0,NA],
)
writetree("test.root", df)
df2 = readtree("test.root")

@test nrow(df2)==nrow(df)
@test colnames(df2)==colnames(df)
@test isna(df[3, "z"])

df2["asd"] = 3.0
@test colnames(df2) == ["x", "y", "z", "asd"]
@test df2["asd"] == [3.0, 3.0, 3.0]

df2[2, "asd"] = -1.0
@test df2["asd"] == [3.0, -1.0, 3.0]

df2[3, "asd"] = NA
@test isna(df2[3, "asd"])

df2["x"] = df2["x"]
@test colnames(df2) == ["x", "y", "z", "asd"]

df2[3, "x"] = 123.0

@test all(df2[:, "y"] .== DataVector["asd", "bsd", "xyz"])
@test all(df2["x"] .== [1.0, 2.0, 123.0])

N=1000
big_df = DataFrame(x=[rand() for x in 1:N], y=[10.0*rand() for x in 1:N], z=[0.0001*rand() for x in 1:N])
tic()
writetree("big_df.root", big_df)
x = toq()
println("wrote $(nrow(big_df)) events, $(length(colnames(big_df))) columns in $x seconds")

big_df2 = TreeDataFrame("big_df.root", "rw")
tic();
big_df3 = readtree("big_df.root")
x = toq()
println("read $(nrow(big_df)) events, $(length(colnames(big_df))) columns in $x seconds")

@test nrow(big_df2)==nrow(big_df3)

br = ROOT.NABranch(convert(Float32, 0.0))
ROOT.attach(br, big_df2.tree, "newcol")

for i=1:nrow(big_df2)
    ROOT.setval!(br, convert(Float32, i))
    ROOT.fill!(br)
end

#cleanup
rm("test.root")
println(df)
println(df2)
