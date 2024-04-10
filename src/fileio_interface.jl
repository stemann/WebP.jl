fileio_load(f::File{format"WebP"}; kwargs...) = decode(f.filename; kwargs...)

function fileio_save(f::File{format"WebP"}, image::AbstractMatrix{<:Colorant}; kwargs...)
    return write_webp(f.filename, image; kwargs...)
end
