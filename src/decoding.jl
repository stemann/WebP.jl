function decode(
    ::Type{TColor}, data::AbstractVector{UInt8}; transpose = false
)::Matrix{TColor} where {TColor <: Colorant}
    TDecodedColor = TColor
    if TColor == ARGB{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeARGB
    elseif TColor == BGR{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeBGR
    elseif TColor == BGRA{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeBGRA
    elseif TColor == RGB{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeRGB
    elseif TColor == RGBA{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeRGBA
    elseif TColor == Gray{N0f8}
        webp_decode_fn = Wrapper.WebPDecodeRGB
        TDecodedColor = RGB{N0f8}
    else
        throw(ArgumentError("Unsupported color type: $TColor"))
    end
    width = Ref{Int32}(-1)
    height = Ref{Int32}(-1)
    decoded_data_ptr = webp_decode_fn(pointer(data), length(data), width, height)
    decoded_data_size = (sizeof(TDecodedColor), Int(width[]), Int(height[]))
    decoded_data = unsafe_wrap(Array{UInt8, 3}, decoded_data_ptr, decoded_data_size)
    image_view = colorview(TDecodedColor, normedview(decoded_data))
    if TDecodedColor == TColor
        image = !transpose ? collect(image_view) : permutedims(image_view, (2, 1))
    else
        image = if !transpose
            TColor.(image_view)
        else
            TColor.(PermutedDimsArray(image_view, (2, 1)))
        end
    end
    Wrapper.WebPFree(decoded_data_ptr)
    return image
end
decode(data::AbstractVector{UInt8}; kwargs...)::Matrix{RGB{N0f8}} =
    decode(RGB{N0f8}, data; kwargs...)

function decode(
    ::Type{CT}, f::Union{String, IO}; kwargs...
)::Matrix{CT} where {CT <: Colorant}
    return decode(CT, Base.read(f); kwargs...)
end
decode(f::Union{String, IO}; kwargs...)::Matrix{RGB{N0f8}} = decode(RGB{N0f8}, f; kwargs...)
