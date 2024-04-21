fileio_load(f::File{format"WebP"}; kwargs...) = read_webp(f.filename; kwargs...)

function fileio_save(f::File{format"WebP"}, image::AbstractMatrix{<:Colorant}; kwargs...)
    return write_webp(f.filename, image; kwargs...)
end
