fileio_load(f::File{format"WebP"}; kwargs...) = read_webp(f.filename; kwargs...)

fileio_load(s::Stream{format"WebP"}; kwargs...) = read_webp(s.io; kwargs...)

function fileio_save(f::File{format"WebP"}, image::AbstractMatrix{<:Colorant}; kwargs...)
    return write_webp(f.filename, image; kwargs...)
end

function fileio_save(s::Stream{format"WebP"}, image::AbstractMatrix{<:Colorant}; kwargs...)
    return write_webp(s.io, image; kwargs...)
end

function fileio_save(
    f::File{format"WebP"}, frames::AbstractArray{<:Colorant, 3}; kwargs...
)
    return write_webp(f.filename, frames; kwargs...)
end

function fileio_save(
    s::Stream{format"WebP"}, frames::AbstractArray{<:Colorant, 3}; kwargs...
)
    return write_webp(s.io, frames; kwargs...)
end
