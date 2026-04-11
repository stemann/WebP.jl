function validate_encoding_quality(lossy::Bool, quality::Real)
    if lossy && !(0 ≤ quality ≤ 100)
        throw(ArgumentError("Quality $quality is not in the range from 0 to 100."))
    end
    return nothing
end

function picture_import!(picture, image::AbstractMatrix{TColor}) where {TColor <: Colorant}
    import_fn = if TColor == BGR{N0f8}
        Wrapper.WebPPictureImportBGR
    elseif TColor == BGRA{N0f8}
        Wrapper.WebPPictureImportBGRA
    elseif TColor == RGB{N0f8}
        Wrapper.WebPPictureImportRGB
    elseif TColor == RGBA{N0f8}
        Wrapper.WebPPictureImportRGBA
    else
        throw(ArgumentError("Unsupported color type: $TColor"))
    end

    stride = size(image, 1) * sizeof(TColor)
    import_fn(picture, pointer(image), stride) != 0 ||
        error("Failed to import frame data for WebP encoding")
    return nothing
end

function prepared_encoding_frame(
    image::AbstractMatrix{TColor}; transpose = false
)::Matrix{TColor} where {TColor <: Colorant}
    return transpose ? Matrix(image) : permutedims(image, (2, 1))
end

function encoder_config(; lossy = false, quality::Real = 75)
    validate_encoding_quality(lossy, quality)

    config = Ref{Wrapper.WebPConfig}()
    Wrapper.WebPConfigPreset(
        config, Wrapper.WEBP_PRESET_DEFAULT, Float32(clamp(quality, 0, 100))
    ) != 0 || error("Failed to initialize WebP encoder configuration")

    if !lossy
        Wrapper.WebPConfigLosslessPreset(config, 6) != 0 ||
            error("Failed to initialize lossless WebP encoder configuration")
    end

    Wrapper.WebPValidateConfig(config) != 0 ||
        error("Invalid WebP encoder configuration")
    return config
end

function encode_frame(
    image::AbstractMatrix{TColor}, config; transpose = false
) where {TColor <: Colorant}
    prepared_image = prepared_encoding_frame(image; transpose)
    width, height = size(prepared_image)

    picture = Ref{Wrapper.WebPPicture}()
    Wrapper.WebPPictureInit(picture) != 0 ||
        error("Failed to initialize WebP picture")
    set_webp_picture_canvas!(picture, width, height)

    try
        picture_import!(picture, prepared_image)
        return picture
    catch
        Wrapper.WebPPictureFree(picture)
        rethrow()
    end
end

function animation_timestamps(frame_durations_ms::AbstractVector{<:Integer})
    timestamps = Int[]
    timestamp_ms = 0
    for duration_ms in frame_durations_ms
        duration_ms >= 0 || throw(ArgumentError("Frame durations must be non-negative."))
        push!(timestamps, timestamp_ms)
        timestamp_ms += duration_ms
    end
    return timestamps, timestamp_ms
end

function animation_timestamps(animation::Animation)
    timestamps = Int[]
    for frame in animation.frames
        frame.duration_ms >= 0 || throw(ArgumentError("Frame durations must be non-negative."))
        start_timestamp_ms = frame.timestamp_ms - frame.duration_ms
        start_timestamp_ms >= 0 ||
            throw(ArgumentError("Animation frame timestamps must not precede their durations."))
        push!(timestamps, start_timestamp_ms)
    end

    issorted(timestamps) || throw(
        ArgumentError("Animation frame timestamps must be in non-decreasing order.")
    )
    isempty(animation.frames) && error("Animated WebP contained no frames")
    return timestamps, last(animation.frames).timestamp_ms
end

function encode_animation_frames(
    frames::AbstractVector{<:AbstractMatrix{TColor}},
    frame_durations_ms::AbstractVector{<:Integer};
    loop_count::Integer = 0,
    background_color::UInt32 = 0x00000000,
    lossy = false,
    quality::Real = 75,
    transpose = false,
) where {TColor <: Colorant}
    isempty(frames) && throw(ArgumentError("Animated WebP encoding requires at least one frame."))
    length(frame_durations_ms) == length(frames) || throw(
        ArgumentError("Expected one frame duration per frame when encoding animated WebP.")
    )

    frame_size = size(first(frames))
    all(frame -> size(frame) == frame_size, frames) || throw(
        ArgumentError("All animated WebP frames must have the same dimensions.")
    )

    timestamps_ms, final_timestamp_ms = animation_timestamps(frame_durations_ms)
    config = encoder_config(; lossy, quality)

    canvas_width, canvas_height = size(prepared_encoding_frame(first(frames); transpose))
    enc_options = Ref{Wrapper.WebPAnimEncoderOptions}()
    Wrapper.WebPAnimEncoderOptionsInit(enc_options) != 0 ||
        error("Failed to initialize animated WebP encoder options")
    enc_opts = enc_options[]
    enc_options[] = Wrapper.WebPAnimEncoderOptions(
        Wrapper.WebPMuxAnimParams(UInt32(background_color), loop_count),
        enc_opts.minimize_size,
        enc_opts.kmin,
        enc_opts.kmax,
        enc_opts.allow_mixed,
        enc_opts.verbose,
        enc_opts.padding,
    )

    encoder = Wrapper.WebPAnimEncoderNew(canvas_width, canvas_height, enc_options)
    encoder == C_NULL && error("Failed to create animated WebP encoder")

    webp_data = Ref{Wrapper.WebPData}()
    Wrapper.WebPDataInit(webp_data)

    try
        for (frame, timestamp_ms) in zip(frames, timestamps_ms)
            picture = encode_frame(frame, config; transpose)
            try
                Wrapper.WebPAnimEncoderAdd(encoder, picture, timestamp_ms, config) != 0 ||
                    error(
                        "Failed to encode animated WebP frame: $(unsafe_string(Wrapper.WebPAnimEncoderGetError(encoder)))"
                    )
            finally
                Wrapper.WebPPictureFree(picture)
            end
        end

        Wrapper.WebPAnimEncoderAdd(encoder, C_NULL, final_timestamp_ms, config) != 0 ||
            error(
                "Failed to finalize animated WebP encoding: $(unsafe_string(Wrapper.WebPAnimEncoderGetError(encoder)))"
            )
        Wrapper.WebPAnimEncoderAssemble(encoder, webp_data) != 0 ||
            error(
                "Failed to assemble animated WebP bitstream: $(unsafe_string(Wrapper.WebPAnimEncoderGetError(encoder)))"
            )

        return unsafe_wrap(Vector{UInt8}, webp_data[].bytes, webp_data[].size) |> collect
    finally
        Wrapper.WebPDataClear(webp_data)
        Wrapper.WebPAnimEncoderDelete(encoder)
    end
end

function encode(
    image::AbstractMatrix{TColor}; lossy = false, quality::Real = 75, transpose = false
)::Vector{UInt8} where {TColor <: Colorant}
    validate_encoding_quality(lossy, quality)

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

    prepared_image = prepared_encoding_frame(image; transpose)
    width, height = size(prepared_image)
    stride = width * sizeof(TColor)

    output_ptr = Ref{Ptr{UInt8}}()
    output_length = if lossy
        webp_encode_fn(
            pointer(prepared_image),
            width,
            height,
            stride,
            Float32(quality),
            output_ptr,
        )
    else
        webp_encode_fn(pointer(prepared_image), width, height, stride, output_ptr)
    end

    output_view = unsafe_wrap(Vector{UInt8}, output_ptr[], output_length)
    output = collect(output_view)
    Wrapper.WebPFree(output_ptr[])
    return output
end

function encode(
    frames::AbstractArray{TColor, 3};
    frame_duration_ms::Integer = 100,
    loop_count::Integer = 0,
    background_color::UInt32 = 0x00000000,
    kwargs...,
)::Vector{UInt8} where {TColor <: Colorant}
    frame_views = [@view(frames[:, :, frame_index]) for frame_index in axes(frames, 3)]
    frame_durations_ms = fill(frame_duration_ms, length(frame_views))
    return encode_animation_frames(
        frame_views,
        frame_durations_ms;
        loop_count,
        background_color,
        kwargs...,
    )
end

function encode(
    animation::Animation{TColor}; lossy = false, quality::Real = 75, transpose = false
)::Vector{UInt8} where {TColor <: Colorant}
    frames = map(frame -> frame.image, animation.frames)
    frame_durations_ms = map(frame -> frame.duration_ms, animation.frames)
    _, final_timestamp_ms = animation_timestamps(animation)
    final_timestamp_ms >= 0 || throw(ArgumentError("Animation timestamps must be non-negative."))
    return encode_animation_frames(
        frames,
        frame_durations_ms;
        loop_count = animation.loop_count,
        background_color = animation.background_color,
        lossy,
        quality,
        transpose,
    )
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

function write_webp(file_path::AbstractString, frames::AbstractArray{<:Colorant, 3}; kwargs...)
    open(file_path, "w") do io
        write_webp(io, frames; kwargs...)
    end
    return nothing
end

function write_webp(io::IO, frames::AbstractArray{<:Colorant, 3}; kwargs...)
    write(io, encode(frames; kwargs...))
    return nothing
end

function write_webp(file_path::AbstractString, animation::Animation; kwargs...)
    open(file_path, "w") do io
        write_webp(io, animation; kwargs...)
    end
    return nothing
end

function write_webp(io::IO, animation::Animation; kwargs...)
    write(io, encode(animation; kwargs...))
    return nothing
end
