struct AnimationFrame{TColor <: Colorant}
    image::Matrix{TColor}
    timestamp_ms::Int
    duration_ms::Int
end

struct Animation{TColor <: Colorant}
    frames::Vector{AnimationFrame{TColor}}
    canvas_size::Tuple{Int, Int}
    loop_count::Int
    background_color::UInt32
end

function animation_frame_stack(animation::Animation{TColor}) where {TColor <: Colorant}
    isempty(animation.frames) && error("Animated WebP contained no frames")
    return cat(map(frame -> frame.image, animation.frames)...; dims = 3)
end

function decoder_color_mode(::Type{TColor}) where {TColor <: Colorant}
    if TColor == ARGB{N0f8}
        return Wrapper.MODE_ARGB
    elseif TColor == BGR{N0f8}
        return Wrapper.MODE_BGR
    elseif TColor == BGRA{N0f8}
        return Wrapper.MODE_BGRA
    elseif TColor == RGB{N0f8}
        return Wrapper.MODE_RGB
    elseif TColor == RGBA{N0f8}
        return Wrapper.MODE_RGBA
    elseif TColor == Gray{N0f8}
        return Wrapper.MODE_RGB
    else
        throw(ArgumentError("Unsupported color type: $TColor"))
    end
end

function decoded_color_type(::Type{TColor}) where {TColor <: Colorant}
    return TColor == Gray{N0f8} ? RGB{N0f8} : TColor
end

function animation_decoded_color_type(::Type{TColor}) where {TColor <: Colorant}
    if TColor == BGRA{N0f8} || TColor == BGR{N0f8}
        return BGRA{N0f8}
    end
    return RGBA{N0f8}
end

function bitstream_features(data::AbstractVector{UInt8})
    features = Ref{Wrapper.WebPBitstreamFeatures}()
    status = Wrapper.WebPGetFeatures(pointer(data), length(data), features)
    status == Wrapper.VP8_STATUS_OK || error("Failed to inspect WebP bitstream: $status")
    return features[]
end

function decode_image_view(
    ::Type{TColor},
    ::Type{TDecodedColor},
    decoded_data::AbstractArray{UInt8, 3};
    transpose = false,
) where {TColor <: Colorant, TDecodedColor <: Colorant}
    image_view = colorview(TDecodedColor, normedview(decoded_data))
    if TDecodedColor == TColor
        return transpose ? collect(image_view) : permutedims(image_view, (2, 1))
    end
    return transpose ? TColor.(image_view) : TColor.(PermutedDimsArray(image_view, (2, 1)))
end

function decode_static(
    ::Type{TColor}, data::AbstractVector{UInt8}; transpose = false
)::Matrix{TColor} where {TColor <: Colorant}
    width = Ref{Int32}(-1)
    height = Ref{Int32}(-1)
    TDecodedColor = decoded_color_type(TColor)

    decoded_data_ptr = if TDecodedColor == ARGB{N0f8}
        Wrapper.WebPDecodeARGB(pointer(data), length(data), width, height)
    elseif TDecodedColor == BGR{N0f8}
        Wrapper.WebPDecodeBGR(pointer(data), length(data), width, height)
    elseif TDecodedColor == BGRA{N0f8}
        Wrapper.WebPDecodeBGRA(pointer(data), length(data), width, height)
    elseif TDecodedColor == RGB{N0f8}
        Wrapper.WebPDecodeRGB(pointer(data), length(data), width, height)
    elseif TDecodedColor == RGBA{N0f8}
        Wrapper.WebPDecodeRGBA(pointer(data), length(data), width, height)
    else
        throw(ArgumentError("Unsupported color type: $TColor"))
    end

    decoded_data_ptr == C_NULL && error("Failed to decode WebP image")

    try
        decoded_data_size = (sizeof(TDecodedColor), Int(width[]), Int(height[]))
        decoded_data = unsafe_wrap(Array{UInt8, 3}, decoded_data_ptr, decoded_data_size)
        return decode_image_view(TColor, TDecodedColor, decoded_data; transpose)
    finally
        Wrapper.WebPFree(decoded_data_ptr)
    end
end

function frame_durations(data::AbstractVector{UInt8}, frame_count::Int)
    durations = Int[]
    GC.@preserve data begin
        webp_data = Ref(Wrapper.WebPData(pointer(data), length(data)))
        demux_state = Ref{Wrapper.WebPDemuxState}(Wrapper.WEBP_DEMUX_DONE)
        demuxer = Wrapper.WebPDemuxPartial(webp_data, demux_state)
        demuxer == C_NULL && error("Failed to create WebP demuxer")

        iter = Ref{Wrapper.WebPIterator}()

        try
            if frame_count > 0 && Wrapper.WebPDemuxGetFrame(demuxer, 1, iter) != 0
                while true
                    push!(durations, Int(iter[].duration))
                    length(durations) == frame_count && break
                    Wrapper.WebPDemuxNextFrame(iter) == 0 && break
                end
            end
        finally
            if !isempty(durations)
                Wrapper.WebPDemuxReleaseIterator(iter)
            end
            Wrapper.WebPDemuxDelete(demuxer)
        end
    end

    if length(durations) != frame_count
        error(
            "Animated WebP metadata mismatch: demuxed $(length(durations)) frame durations for $frame_count frames"
        )
    end

    return durations
end

function decode_animation(
    ::Type{TColor}, data::AbstractVector{UInt8}; transpose = false
)::Animation{TColor} where {TColor <: Colorant}
    features = bitstream_features(data)
    features.has_animation != 0 || throw(ArgumentError("WebP image is not animated"))

    frames = AnimationFrame{TColor}[]
    info = Ref{Wrapper.WebPAnimInfo}()

    GC.@preserve data begin
        webp_data = Ref(Wrapper.WebPData(pointer(data), length(data)))
        dec_options = Ref{Wrapper.WebPAnimDecoderOptions}()
        status = Wrapper.WebPAnimDecoderOptionsInit(dec_options)
        status != 0 || error("Failed to initialize animated WebP decoder options")
        dec_opts = dec_options[]
        TAnimDecodedColor = animation_decoded_color_type(TColor)
        dec_options[] = Wrapper.WebPAnimDecoderOptions(
            decoder_color_mode(TAnimDecodedColor), dec_opts.use_threads, dec_opts.padding
        )

        decoder = Wrapper.WebPAnimDecoderNew(webp_data, dec_options)
        decoder == C_NULL && error("Failed to create animated WebP decoder")

        Wrapper.WebPAnimDecoderGetInfo(decoder, info) != 0 ||
            error("Failed to read animated WebP metadata")

        durations = frame_durations(data, Int(info[].frame_count))
        frame_index = 1

        try
            while Wrapper.WebPAnimDecoderHasMoreFrames(decoder) != 0
                frame_ptr = Ref{Ptr{UInt8}}()
                timestamp = Ref{Cint}()
                Wrapper.WebPAnimDecoderGetNext(decoder, frame_ptr, timestamp) != 0 ||
                    error("Failed to decode animated WebP frame $frame_index")

                decoded_data_size = (
                    sizeof(TAnimDecodedColor),
                    Int(info[].canvas_width),
                    Int(info[].canvas_height),
                )
                decoded_data = unsafe_wrap(Array{UInt8, 3}, frame_ptr[], decoded_data_size)
                image = decode_image_view(TColor, TAnimDecodedColor, decoded_data; transpose)
                push!(
                    frames,
                    AnimationFrame{TColor}(image, Int(timestamp[]), durations[frame_index]),
                )
                frame_index += 1
            end
        finally
            Wrapper.WebPAnimDecoderDelete(decoder)
        end
    end

    length(frames) == Int(info[].frame_count) || error(
        "Animated WebP metadata mismatch: decoded $(length(frames)) frames for $(Int(info[].frame_count)) advertised frames"
    )

    canvas_size = transpose ? (Int(info[].canvas_width), Int(info[].canvas_height)) :
        (Int(info[].canvas_height), Int(info[].canvas_width))
    return Animation{TColor}(
        frames, canvas_size, Int(info[].loop_count), UInt32(info[].bgcolor)
    )
end

function decode_animation(
    data::AbstractVector{UInt8}; kwargs...
)::Union{Animation{RGB{N0f8}}, Animation{RGBA{N0f8}}}
    features = bitstream_features(data)
    has_alpha = features.has_alpha != 0
    TColor = has_alpha ? RGBA{N0f8} : RGB{N0f8}
    return decode_animation(TColor, data; kwargs...)
end

function decode(
    ::Type{TColor}, data::AbstractVector{UInt8}; animated = false, kwargs...
) where {TColor <: Colorant}
    if animated
        return animation_frame_stack(decode_animation(TColor, data; kwargs...))
    end
    return decode_static(TColor, data; kwargs...)
end

function decode(data::AbstractVector{UInt8}; animated = false, kwargs...)
    features = bitstream_features(data)
    has_alpha = features.has_alpha != 0
    TColor = has_alpha ? RGBA{N0f8} : RGB{N0f8}
    return decode(TColor, data; animated, kwargs...)
end

function read_webp(::Type{CT}, f::Union{AbstractString, IO}; kwargs...) where {CT <: Colorant}
    return decode(CT, Base.read(f); kwargs...)
end

function read_webp(f::Union{AbstractString, IO}; kwargs...)
    return decode(Base.read(f); kwargs...)
end

function read_webp_animation(
    ::Type{CT}, f::Union{AbstractString, IO}; kwargs...
)::Animation{CT} where {CT <: Colorant}
    return decode_animation(CT, Base.read(f); kwargs...)
end

function read_webp_animation(
    f::Union{AbstractString, IO}; kwargs...
)::Union{Animation{RGB{N0f8}}, Animation{RGBA{N0f8}}}
    data = Base.read(f)
    features = bitstream_features(data)
    has_alpha = features.has_alpha != 0
    TColor = has_alpha ? RGBA{N0f8} : RGB{N0f8}
    return decode_animation(TColor, data; kwargs...)
end
