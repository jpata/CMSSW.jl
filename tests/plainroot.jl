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
@test isna(df[3, :z])

df2[:asd] = 3.0
@test names(df2) == [:x, :y, :z, :asd]
@test df2[:asd] == [3.0, 3.0, 3.0]

df2[2, :asd] = -1.0
@test df2[:asd] == [3.0, -1.0, 3.0]

df2[3, :asd] = NA
@test isna(df2[3, :asd])

df2[:x] = df2[:x]
@test names(df2) == [:x, :y, :z, :asd]

df2[3, :x] = 123.0

@test all(df2[:, :y] .== DataArray(ASCIIString["asd", "bsd", "xyz"], Bool[0,0,0]))
@test all(df2[:x] .== [1.0, 2.0, 123.0])

N = 1000000
big_df = DataFrame(
	x=Int64[x for x in 1:N],
	y=Float64[10.0*rand() for x in 1:N],
	z=Float64[0.0001*rand() for x in 1:N]
)
tic()
writetree("big_df.root", big_df)
x = toq()
println("wrote $(nrow(big_df)) events, $(length(names(big_df))) columns in $x seconds")

big_df2 = TreeDataFrame("big_df.root", "rw")
bdf = big_df2[:,:]
@test nrow(bdf) == nrow(big_df)

#cleanup
rm("test.root")

tf = TFile("test.root", "RECREATE")
cd(tf)

hi = new_th1d("myhist1d_1", linspace(-1,1, 10), [100*i for i=1:9], [10*i for i=1:9])
write(hi)
@test get_contents_errors(hi) == ([100*i for i=1:9], [10*i for i=1:9])

hi = new_th1d("myhist1d_2",
	vcat(-Inf, [-1.0, 0.0, 1.0], Inf),
	[100*i for i=1:4],
	[10*i for i=1:4]
)
@test get_contents_errors(hi) == ([100*i for i=1:4], [10*i for i=1:4])
write(hi)

cont  = zeros(Float64, 4,4)
err = zeros(Float64, 4,4)
for i=1:4
	for j=1:4
		cont[i,j] = 10*i+j
		err[i,j] = 10*i + j
	end
end
hi = new_th2d("myhist2d_1",
	vcat(-Inf, [-1.0, 0.0, 1.0], Inf), vcat(-Inf, [-1.0, 0.0, 1.0], Inf),
	cont, err,
)
@test get_contents_errors(hi) == (cont, err)
write(hi)

cont  = zeros(Float64, 4,9)
err = zeros(Float64, 4,9)
for i=1:4
	for j=1:9
		cont[i,j] = 10*i+j
		err[i,j] = 10*i + j
	end
end

hi = new_th2d("myhist2d_2",
	vcat(-Inf, [-1.0, 0.0, 1.0], Inf), vcat(-Inf, linspace(-1, 1, 8), Inf),
	cont, err,
)
write(hi)
@test get_contents_errors(hi) == (cont, err)

close(tf)
