function strcpy(a, b)
    assert(length(b)<length(a))
    unsafe_copy!(
        pointer(convert(Vector{Uint8}, a)),
        pointer(vcat(convert(Vector{Uint8}, b), [convert(Uint8,0)])),
        length(b)
    )
end
@deprecate strcpy :nothing