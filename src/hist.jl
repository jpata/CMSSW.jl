import Base.size

function removeinf(arr)
    for i=1:length(arr)
        if arr[i]==-Inf
            arr[i] = -e^10#nextfloat(-Inf)
        end
        if arr[i]==Inf
            arr[i] = e^10#prevfloat(Inf)
        end
    end
    return arr
end


abstract THist
immutable TH1D <: THist
    p::Ptr{Void}
end
immutable TH2D <: THist
    p::Ptr{Void}
end

Base.write(h::THist) = write(h.p)

function get_n_bins(h::THist, n::Integer)
    return ccall(
        (:th1d_get_n_bins, libplainroot),
        Cint, (
            Ptr{Uint8},
            Cint
        ), h.p, n
    )
end

#+2 to account for under- and overflow
Base.size(h::TH1D) = (get_n_bins(h, 1)+2, )
Base.size(h::TH2D) = (get_n_bins(h, 1)+2, get_n_bins(h, 2)+2, )

function new_th1d(
    name::ASCIIString,
    edges::AbstractVector, #low_under, low_1, low_2, ... , low_over, high_over
    bins::AbstractVector, #under, c1, c2, ... , over
    errors::AbstractVector,
    entries::AbstractVector=Float64[],
    labels::AbstractVector=ASCIIString[]
)
    @assert length(edges)==length(bins)+1
    @assert length(edges)==length(errors)+1

    any((bins .> 0) & (errors .> bins)) &&
        warn("errors > entries: \n", string(hcat(bins, errors)))

    #remove underflow low and overflow high edges
    edges = deepcopy(edges[2:length(edges)-1])

    removeinf(edges)
    @assert !any(isnan(edges))

    if length(labels)==0
        labels = [@sprintf("[%.2f,%.2f)", edges[i-1], edges[i]) for i=2:length(edges)]
    end
    @assert length(edges)==length(labels)+1

    for i=1:length(edges)
        if edges[i]==-Inf
            edges[i] = -e^10#nextfloat(-Inf)
        end
        if edges[i]==Inf
            edges[i] = e^10#prevfloat(Inf)
        end
        if isnan(edges[i])
            error("edges must not contain nan: ", join(edges, ","))
        end
    end

    hi = ccall(
       (:new_th1d, libplainroot),
       Ptr{Void},
       (Ptr{Uint8}, Cuint,
        Ptr{Cdouble}, Ptr{Cdouble},
        Ptr{Cdouble}, Ptr{Ptr{Uint8}},
        Cdouble
        ),
       name, length(edges),
       convert(Vector{Float64}, edges),
       convert(Vector{Float64}, bins),
       convert(Vector{Float64}, errors),
       convert(Vector{ASCIIString}, labels),
       sum(entries)
    )
    return TH1D(hi)
end

function new_th2d(
    name::ASCIIString,
    edges_x::Array{Float64, 1},
    edges_y::Array{Float64, 1},
    bins::Array{Float64, 2},
    errors::Array{Float64, 2},
    entries::Array{Float64, 2}=Array(Float64, 0,0),
    labels_x=[],
    labels_y=[],
)
    @assert size(bins)==size(errors)
    nx, ny = size(bins)
    @assert length(edges_x) == nx+1 "$(length(edges_x)) != $(nx+1) \n $edges_x"
    @assert length(edges_y) == ny+1 "$(length(edges_y)) != $(ny+1) \n $edges_x"

    edges_x = deepcopy(edges_x[2:length(edges_x)-1])
    edges_y = deepcopy(edges_y[2:length(edges_y)-1])

    removeinf(edges_x)
    removeinf(edges_y)

    @assert !any(isnan(edges_x))
    @assert !any(isnan(edges_y))

    if length(labels_x)==0
        labels_x = [@sprintf("x=[%.2f,%.2f)", edges_x[i-1], edges_x[i]) for i=2:length(edges_x)]
    end
    if length(labels_y)==0
        labels_y = [@sprintf("y=[%.2f,%.2f)", edges_y[i-1], edges_y[i]) for i=2:length(edges_y)]
    end
    @assert length(edges_x)==length(labels_x)+1
    @assert length(edges_y)==length(labels_y)+1

    pbins = [pointer(bins[i,:]) for i=1:nx]
    perrs = [pointer(errors[i,:]) for i=1:nx]
    hi = ccall(
       (:new_th2d, libplainroot),
       Ptr{Void},
       (
        Ptr{Uint8},
        Cuint, Cuint,
        Ptr{Cdouble}, Ptr{Cdouble}, #edges_x, edges_y
        Ptr{Ptr{Cdouble}}, Ptr{Ptr{Cdouble}}, #bins, errors
        Ptr{Ptr{Uint8}}, Ptr{Ptr{Uint8}}, #labels
        Cdouble #nentries
        ),
       name, length(edges_x), length(edges_y),
       edges_x, edges_y, pbins, perrs,
       convert(Vector{ASCIIString}, labels_x), convert(Vector{ASCIIString}, labels_y),
       sum(entries)
    )
    TH2D(hi)
end

function set_axis_label(h::THist, label, n::Integer=1)
    ccall(
        (:set_axis_label, libplainroot),
        Void, (
            Ptr{Void},
            Cint,
            Ptr{Uint8}
        ), h.p, n, convert(ASCIIString, label),
    )
end


for a in Symbol[:TH1D]
    for b in Symbol[:content, :error]
        eval(
            quote
                function $(symbol("get_bin_$(string(b))"))(x::$(a), n::Int64)
                    !(n>=0 && n<=size(x)[1]) && error("$n out of bounds [0, $(size(x)[1])]")
                    return ccall(
                        (
                            $(lowercase(string(a, "_get_bin_", b))), #func name as spliced string
                            libplainroot #library
                        ),
                        Cdouble, #ret
                        (Ptr{Void}, Cint), #argtypes
                        x.p, n #args
                    )
                end
            end
        )
    end
end

for a in Symbol[:TH2D]
    for b in Symbol[:content, :error]
        eval(
            quote
                function $(symbol("get_bin_$(string(b))"))(x::$(a), n::Int64, m::Int64)
                    !(n>=0 && n<size(x)[1]) && error("$n out of bounds [0, $(size(x)[1])]")
                    !(m>=0 && m<size(x)[2]) && error("$m out of bounds [0, $(size(x)[2])]")

                    return ccall(
                        (
                            $(lowercase(string(a, "_get_bin_", b))), #func name as spliced string
                            libplainroot #library
                        ),
                        Cdouble, #ret
                        (Ptr{Void}, Cint, Cint), #argtypes
                        x.p, n, m #args
                    )
                end
            end
        )
    end
end

function get_contents_errors(h::TH2D)
    dims = size(h)
    @assert length(dims)==2

    conts = zeros(Float64, dims...)
    errs = zeros(Float64, dims...)

    for i=0:dims[1]-1
        for j=0:dims[2]-1
            conts[i+1,j+1] = get_bin_content(h, i, j)
            errs[i+1,j+1] = get_bin_error(h, i, j)
        end
    end
    return conts, errs
end

function get_contents_errors(h::TH1D)
    dims = size(h)
    @assert length(dims)==1

    conts = zeros(Float64, dims...)
    errs = zeros(Float64, dims...)

    for i=0:dims[1]-1
        conts[i+1] = get_bin_content(h, i)
        errs[i+1] = get_bin_error(h, i)
    end
    return conts, errs
end

export get_contents_errors, TH1D, TH2D
