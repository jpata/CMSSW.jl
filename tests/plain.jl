using ROOT
using DataFrames
using Base.Test

df = DataFrame(
    x = DataArray(Float64[1.0, 2.0, 0.0], Bool[0,0,1]),
    y = DataArray(ASCIIString["asd", "bsd", "xyz"], Bool[0,0,0]),
    z = DataArray(Float64[4.0, 5.0, 0.0], Bool[0,0,1]),
)
writetree("test.root", df)
df2 = readtree("test.root")

@test nrow(df2)==nrow(df)
@test names(df2)==names(df)
@test isna(df[3, "z"])

df2["asd"] = 3.0
@test names(df2) == ["x", "y", "z", "asd"]
@test df2["asd"] == [3.0, 3.0, 3.0]

df2[2, "asd"] = -1.0
@test df2["asd"] == [3.0, -1.0, 3.0]

df2[3, "asd"] = NA
@test isna(df2[3, "asd"])

df2["x"] = df2["x"]
@test names(df2) == ["x", "y", "z", "asd"]

df2[3, "x"] = 123.0

@test all(df2[:, "y"] .== DataArray(ASCIIString["asd", "bsd", "xyz"], Bool[0,0,0]))
@test all(df2["x"] .== [1.0, 2.0, 123.0])

N=1000
big_df = DataFrame(x=Int64[x for x in 1:N], y=Float64[10.0*rand() for x in 1:N], z=Float64[0.0001*rand() for x in 1:N])
tic()
writetree("big_df.root", big_df)
x = toq()
println("wrote $(nrow(big_df)) events, $(length(names(big_df))) columns in $x seconds")

big_df2 = TreeDataFrame("big_df.root", "rw")

#big_df2["third"] = int(0)
#for i=1:nrow(big_df2)
#    big_df2[i, "third"] = i
#end
#writetree("big_df2.root", big_df2)

#tic();
#big_df3 = readtree("big_df2.root")
#println(names(big_df3))
#x = toq()
#println("read $(nrow(big_df)) events, $(length(names(big_df))) columns in $x seconds")
#println(big_df3)
#
#@test_approx_eq_eps sum(big_df3[1] - big_df[1]) 0 e^-5
#@test_approx_eq_eps sum(big_df3[2] - big_df[2]) 0 e^-5
#@test_approx_eq_eps sum(big_df3[3] - big_df[3]) 0 e^-5
#
#@test all(big_df3[4] .== Int64[1:nrow(big_df)])

#cleanup
rm("test.root")
