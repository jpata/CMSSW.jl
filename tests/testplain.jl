using ROOT
using DataFrames


df = DataFrame(
    x=DataVector[1.0,2.0,NA],
    y=DataVector["asd", "bsd", NA],
    z=DataVector[4,5.0,NA],
)
writetree("test.root", df)
df2 = readtree("test.root")
println(df)
println(df2)