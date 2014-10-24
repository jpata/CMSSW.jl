
type TFile
    p::Ptr{Void} #pointer to TFile
    s::String #file name
end

#Call new TFile(fname, op)
function TFile(fname::String, op="")
    tf = ccall(
        (:new_tfile, libplainroot),
        Ptr{Void}, (Ptr{Uint8}, Ptr{Uint8}), string(fname), string(op)
    )
    if tf == C_NULL
        error("failed to open TFile $(string(fname))")
    end
    return TFile(tf, fname)
end

#Call TFile::Close
function Base.close(tf::TFile)
    @assert tf.p != C_NULL "TFile was already closed"
    ccall(
        (:tfile_close, libplainroot),
        Void, (Ptr{Void}, ), tf.p
    )
    tf.p = C_NULL
end


#Call TFile::Get(const char* key)
Base.get(tf::TFile, key) = ccall(
    (:tfile_get, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)
#Call TFile::mkdir(const char* key)
Base.mkdir(tf::Ptr{Void}, key) = ccall(
    (:tfile_mkdir, libplainroot),
    Ptr{Void}, (Ptr{Void}, Ptr{Uint8}), tf, string(key)
)

Base.mkdir(tf::TFile, key) = mkdir(tf.p, key)

Base.cd(tf::TFile, key="") = ccall(
    (:tfile_cd, libplainroot),
    Bool, (Ptr{Void}, Ptr{Uint8}), tf.p, string(key)
)

ls(tf::TFile) = ccall(
    (:tfile_ls, libplainroot),
    Void, (Ptr{Void}, ), tf.p,
)
