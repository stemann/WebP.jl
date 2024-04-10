fileio_load(f::File{format"WebP"}; kwargs...) = decode(f.filename; kwargs...)
