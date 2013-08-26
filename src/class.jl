using Clang.cindex

immutable Derp
    x::Cint
    y::Cint
end


function new_Derp()
    return ccall((:new_Derp, "libclass"), Ptr{Void}, ())
end

function modify_Derp(d::Derp)
    aderp = [d]
    ccall((:modify_Derp, "libclass"), Void, (Ptr{Derp}, ), aderp)
    newderp = aderp[1]
    return newderp
end

pderp = new_Derp()
my_derp = unsafe_load(convert(Ptr{Derp}, pderp))
println(my_derp)
#modify_Derp(my_derp); println(my_derp)
