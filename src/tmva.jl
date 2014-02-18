using JSON

immutable TMVAReader
	p::Ptr{Void}
	varbufs::Dict{Symbol, Vector{Float64}}
end

function TMVAReader(name::ASCIIString)
	p = ccall((:new_tmva_reader, libplainroot),
		Ptr{Void},
		(Ptr{Uint8},),
		name
	) 
	TMVAReader(p, Dict{Symbol, Vector{Float64}}())
end

function add_variable!(r::TMVAReader, name::Symbol, var_type=:variable)
	name in keys(r.varbufs) && error("variable $name is already in variable buffers: $(r.varbufs)")
	r.varbufs[name] = Float64[0.0]
	if var_type==:variable
		const vt = 0
	elseif var_type==:spectator
		const vt = 1
	else
		error("unrecognized var_type=$var_type")
	end

	ccall((:tmva_reader_add_variable, libplainroot),
		Void,
		(Ptr{Void}, Ptr{Uint8}, Ptr{Float64}, Cuint),
		r.p, string(name), r.varbufs[name], vt
	) 
end

function book_mva!(r::TMVAReader, name::ASCIIString, weight_file::ASCIIString)
	ccall((:tmva_book_mva, libplainroot),
		Void,
		(Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}),
		r.p, string(name), string(weight_file)
	) 
end

function evaluate_mva(r::TMVAReader, name::ASCIIString)
	do_evaluate = true
	for (k, v) in varbufs
		if isnan(v[1])
			do_evaluate = false
			break
		end
	end

	if do_evaluate
		ccall((:tmva_evaluate_mva, libplainroot),
			Cdouble,
			(Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}),
			r.p, string(name),
		)
	else
		return nan(Float64)
	end
end

function update_var!(r::TMVAReader, s::Symbol, v::Float64)
	r.varbufs[s] = v
end

function from_json(fn::ASCIIString, mva_name::ASCIIString="mva")
	d = JSON.parse(readall(fn))
	"variables" in keys(d) || error("no variables defined: $d")
	"weightfile" in keys(d) || error("no weightfile defined: $d")
	"spectators" in keys(d) || warn("no spectators defined: $d")
	reader = TMVAReader("mva")
	for v in d["variables"]
		add_variable!(reader, symbol(v), :variable)
	end
	for v in d["spectators"]
		add_variable!(reader, symbol(v), :spectator)
	end
	book_mva!(reader, mva_name, d["weightfile"])
	return reader
end

export TMVAReader, add_variable!, book_mva!, evaluate_mva, from_json