function WebPAnimDecoderOptionsInit(dec_options)
    return WebPAnimDecoderOptionsInitInternal(dec_options, WEBP_DEMUX_ABI_VERSION)
end

function WebPAnimDecoderNew(webp_data, dec_options)
    return WebPAnimDecoderNewInternal(webp_data, dec_options, WEBP_DEMUX_ABI_VERSION)
end

function WebPAnimEncoderOptionsInit(enc_options)
    return WebPAnimEncoderOptionsInitInternal(enc_options, WEBP_MUX_ABI_VERSION)
end

function WebPAnimEncoderNew(width, height, enc_options)
    return WebPAnimEncoderNewInternal(width, height, enc_options, WEBP_MUX_ABI_VERSION)
end

function WebPConfigInit(config)
    return WebPConfigInitInternal(
        config, WEBP_PRESET_DEFAULT, Cfloat(75), WEBP_ENCODER_ABI_VERSION
    )
end

function WebPConfigPreset(config, preset, quality)
    return WebPConfigInitInternal(config, preset, quality, WEBP_ENCODER_ABI_VERSION)
end

function WebPDataInit(webp_data)
    webp_data_ptr = Base.unsafe_convert(Ptr{WebPData}, webp_data)
    webp_data_ptr == C_NULL && return nothing
    unsafe_store!(webp_data_ptr, WebPData(C_NULL, 0))
    return nothing
end

function WebPDataClear(webp_data)
    webp_data_ptr = Base.unsafe_convert(Ptr{WebPData}, webp_data)
    webp_data_ptr == C_NULL && return nothing
    WebPFree(unsafe_load(webp_data_ptr).bytes)
    WebPDataInit(webp_data_ptr)
    return nothing
end

function WebPDataCopy(src, dst)
    src_ptr = Base.unsafe_convert(Ptr{WebPData}, src)
    dst_ptr = Base.unsafe_convert(Ptr{WebPData}, dst)
    (src_ptr == C_NULL || dst_ptr == C_NULL) && return 0

    WebPDataInit(dst_ptr)
    src_data = unsafe_load(src_ptr)
    if src_data.bytes != C_NULL && src_data.size != 0
        copied_bytes = convert(Ptr{UInt8}, WebPMalloc(src_data.size))
        copied_bytes == C_NULL && return 0
        unsafe_copyto!(copied_bytes, src_data.bytes, Int(src_data.size))
        unsafe_store!(dst_ptr, WebPData(copied_bytes, src_data.size))
    end
    return 1
end

function WebPDemux(data)
    return WebPDemuxInternal(data, 0, C_NULL, WEBP_DEMUX_ABI_VERSION)
end

function WebPDemuxPartial(data, state)
    return WebPDemuxInternal(data, 1, state, WEBP_DEMUX_ABI_VERSION)
end

function WebPGetFeatures(data, data_size, features)
    return WebPGetFeaturesInternal(data, data_size, features, WEBP_DECODER_ABI_VERSION)
end

function WebPIDecGetYUV(idec, last_y, u, v, width, height, stride, uv_stride)
    return WebPIDecGetYUVA(
        idec, last_y, u, v, C_NULL, width, height, stride, uv_stride, C_NULL
    )
end

function WebPInitDecBuffer(buffer)
    return WebPInitDecBufferInternal(buffer, WEBP_DECODER_ABI_VERSION)
end

function WebPInitDecoderConfig(config)
    return WebPInitDecoderConfigInternal(config, WEBP_DECODER_ABI_VERSION)
end

function WebPIsPremultipliedMode(mode)
    return Cint(
        mode == MODE_rgbA ||
        mode == MODE_bgrA ||
        mode == MODE_Argb ||
        mode == MODE_rgbA_4444
    )
end

function WebPIsAlphaMode(mode)
    return Cint(
        mode == MODE_RGBA ||
        mode == MODE_BGRA ||
        mode == MODE_ARGB ||
        mode == MODE_RGBA_4444 ||
        mode == MODE_YUVA ||
        WebPIsPremultipliedMode(mode) != 0
    )
end

function WebPIsRGBMode(mode)
    return Cint(mode < MODE_YUV)
end

function WebPMuxCreate(bitstream, copy_data)
    return WebPMuxCreateInternal(bitstream, copy_data, WEBP_MUX_ABI_VERSION)
end

function WebPMuxNew()
    return WebPNewInternal(WEBP_MUX_ABI_VERSION)
end

function WebPPictureInit(picture)
    return WebPPictureInitInternal(picture, WEBP_ENCODER_ABI_VERSION)
end
