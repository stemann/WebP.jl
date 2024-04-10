function encode(
    image::Matrix{TColor}; quality::Union{Int, Nothing} = nothing, transpose = false
)::Vector{UInt8} where {TColor <: Colorant}
    lossy = !isnothing(quality)
    if TColor == BGR{N0f8}
        webp_encode_fn = lossy ? Wrapper.WebPEncodeBGR : Wrapper.WebPEncodeLosslessBGR
    elseif TColor == BGRA{N0f8}
        webp_encode_fn = lossy ? Wrapper.WebPEncodeBGRA : Wrapper.WebPEncodeLosslessBGRA
    elseif TColor == RGB{N0f8}
        webp_encode_fn = lossy ? Wrapper.WebPEncodeRGB : Wrapper.WebPEncodeLosslessRGB
    elseif TColor == RGBA{N0f8}
        webp_encode_fn = lossy ? Wrapper.WebPEncodeRGBA : Wrapper.WebPEncodeLosslessRGBA
    else
        throw(ArgumentError("Unsupported color type: $TColor"))
    end

    if !transpose # TODO the kwarg transpose is quite confusing/misleading
        image = permutedims(image, (2, 1))
    end

    height, width = size(image)
    stride = width * sizeof(TColor)
    output_ptr = Ref{Ptr{UInt8}}()
    if lossy
        quality_factor = quality / 100.0f0
        output_length = webp_encode_fn(
            pointer(image), width, height, stride, quality_factor, output_ptr
        )
    else
        output_length = webp_encode_fn(pointer(image), width, height, stride, output_ptr)
    end
    output_view = unsafe_wrap(Vector{UInt8}, output_ptr[], output_length)
    output = collect(output_view)
    Wrapper.WebPFree(output_ptr[])
    return output
end

function write_webp(file_path::AbstractString, image::AbstractMatrix{<:Colorant}; kwargs...)
    open(file_path, "w") do io
        write_webp(io, image; kwargs...)
    end
    return nothing
end

function write_webp(io::IO, image::AbstractMatrix{<:Colorant}; kwargs...)
    write(io, encode(image; kwargs...))
    return nothing
end
