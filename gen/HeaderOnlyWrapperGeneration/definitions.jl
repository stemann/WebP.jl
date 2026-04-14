const FORWARDED_HEADER_ONLY_WRAPPERS = Dict(
    "WebPAnimDecoderNew" => (
        arguments = [:webp_data, :dec_options],
        callee = :WebPAnimDecoderNewInternal,
        call_arguments = Any[:webp_data, :dec_options, :WEBP_DEMUX_ABI_VERSION],
    ),
    "WebPAnimDecoderOptionsInit" => (
        arguments = [:dec_options],
        callee = :WebPAnimDecoderOptionsInitInternal,
        call_arguments = Any[:dec_options, :WEBP_DEMUX_ABI_VERSION],
    ),
    "WebPAnimEncoderOptionsInit" => (
        arguments = [:enc_options],
        callee = :WebPAnimEncoderOptionsInitInternal,
        call_arguments = Any[:enc_options, :WEBP_MUX_ABI_VERSION],
    ),
    "WebPAnimEncoderNew" => (
        arguments = [:width, :height, :enc_options],
        callee = :WebPAnimEncoderNewInternal,
        call_arguments = Any[:width, :height, :enc_options, :WEBP_MUX_ABI_VERSION],
    ),
    "WebPConfigInit" => (
        arguments = [:config],
        callee = :WebPConfigInitInternal,
        call_arguments = Any[
            :config, :WEBP_PRESET_DEFAULT, :(Cfloat(75)), :WEBP_ENCODER_ABI_VERSION
        ],
    ),
    "WebPConfigPreset" => (
        arguments = [:config, :preset, :quality],
        callee = :WebPConfigInitInternal,
        call_arguments = Any[:config, :preset, :quality, :WEBP_ENCODER_ABI_VERSION],
    ),
    "WebPDemux" => (
        arguments = [:data],
        callee = :WebPDemuxInternal,
        call_arguments = Any[:data, 0, :C_NULL, :WEBP_DEMUX_ABI_VERSION],
    ),
    "WebPDemuxPartial" => (
        arguments = [:data, :state],
        callee = :WebPDemuxInternal,
        call_arguments = Any[:data, 1, :state, :WEBP_DEMUX_ABI_VERSION],
    ),
    "WebPGetFeatures" => (
        arguments = [:data, :data_size, :features],
        callee = :WebPGetFeaturesInternal,
        call_arguments = Any[:data, :data_size, :features, :WEBP_DECODER_ABI_VERSION],
    ),
    "WebPInitDecBuffer" => (
        arguments = [:buffer],
        callee = :WebPInitDecBufferInternal,
        call_arguments = Any[:buffer, :WEBP_DECODER_ABI_VERSION],
    ),
    "WebPInitDecoderConfig" => (
        arguments = [:config],
        callee = :WebPInitDecoderConfigInternal,
        call_arguments = Any[:config, :WEBP_DECODER_ABI_VERSION],
    ),
    "WebPMuxCreate" => (
        arguments = [:bitstream, :copy_data],
        callee = :WebPMuxCreateInternal,
        call_arguments = Any[:bitstream, :copy_data, :WEBP_MUX_ABI_VERSION],
    ),
    "WebPMuxNew" => (
        arguments = Symbol[],
        callee = :WebPNewInternal,
        call_arguments = Any[:WEBP_MUX_ABI_VERSION],
    ),
    "WebPPictureInit" => (
        arguments = [:picture],
        callee = :WebPPictureInitInternal,
        call_arguments = Any[:picture, :WEBP_ENCODER_ABI_VERSION],
    ),
)

const MANUAL_HEADER_ONLY_WRAPPERS = Dict(
    "WebPDataClear" => :(
        function WebPDataClear(webp_data)
            webp_data_ptr = Base.unsafe_convert(Ptr{WebPData}, webp_data)
            webp_data_ptr == C_NULL && return nothing
            WebPFree(unsafe_load(webp_data_ptr).bytes)
            WebPDataInit(webp_data_ptr)
            return nothing
        end
    ),
    "WebPDataCopy" => :(
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
    ),
    "WebPDataInit" => :(
        function WebPDataInit(webp_data)
            webp_data_ptr = Base.unsafe_convert(Ptr{WebPData}, webp_data)
            webp_data_ptr == C_NULL && return nothing
            unsafe_store!(webp_data_ptr, WebPData(C_NULL, 0))
            return nothing
        end
    ),
    "WebPIDecGetYUV" => :(
        function WebPIDecGetYUV(idec, last_y, u, v, width, height, stride, uv_stride)
            return WebPIDecGetYUVA(
                idec, last_y, u, v, C_NULL, width, height, stride, uv_stride, C_NULL
            )
        end
    ),
    "WebPIsAlphaMode" => :(
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
    ),
    "WebPIsPremultipliedMode" => :(
        function WebPIsPremultipliedMode(mode)
            return Cint(
                mode == MODE_rgbA ||
                mode == MODE_bgrA ||
                mode == MODE_Argb ||
                mode == MODE_rgbA_4444
            )
        end
    ),
    "WebPIsRGBMode" => :(
        function WebPIsRGBMode(mode)
            return Cint(mode < MODE_YUV)
        end
    ),
)
