using Base64
using ColorTypes
using FixedPointNumbers
using Test
using WebP

const Wrapper = WebP.Wrapper

@testset "Wrapper convenience methods" begin
    static_data = WebP.encode(fill(RGB{N0f8}(1, 0, 0), 1, 1))
    animation_data = base64decode(
        "UklGRlIAAABXRUJQVlA4WAoAAAASAAAAAAAAAAAAQU5JTQYAAAD/////AABBTk1GJgAAAAAAAAAAAAAAAAAAAGQAAABWUDhMDQAAAC8AAAAQBxAREYiI/gcA"
    )

    @testset "Config and picture init" begin
        config = Ref{Wrapper.WebPConfig}()
        @test Wrapper.WebPConfigInit(config) != 0
        @test config[].lossless == 0
        @test config[].quality == 75
        @test Wrapper.WebPValidateConfig(config) != 0
        @test Wrapper.WebPConfigPreset(config, Wrapper.WEBP_PRESET_PHOTO, 42f0) != 0
        @test config[].quality == 42f0

        picture = Ref{Wrapper.WebPPicture}()
        @test Wrapper.WebPPictureInit(picture) != 0
        @test picture[].use_argb == 0
        @test picture[].colorspace == Wrapper.WEBP_YUV420
    end

    @testset "WebPData helpers" begin
        source_bytes = UInt8[0x01, 0x02, 0x03]
        dst = Ref{Wrapper.WebPData}()

        Wrapper.WebPDataInit(dst)
        @test dst[].bytes == C_NULL
        @test dst[].size == 0

        GC.@preserve source_bytes begin
            src = Ref(Wrapper.WebPData(pointer(source_bytes), length(source_bytes)))
            @test Wrapper.WebPDataCopy(src, dst) == 1
            @test dst[].bytes != C_NULL
            @test dst[].bytes != src[].bytes
            @test dst[].size == length(source_bytes)
            @test unsafe_wrap(Vector{UInt8}, dst[].bytes, Int(dst[].size)) == source_bytes
        end

        Wrapper.WebPDataClear(dst)
        @test dst[].bytes == C_NULL
        @test dst[].size == 0
    end

    @testset "Decoder helpers" begin
        @test Wrapper.WebPIsPremultipliedMode(Wrapper.MODE_rgbA) != 0
        @test Wrapper.WebPIsPremultipliedMode(Wrapper.MODE_RGBA) == 0
        @test Wrapper.WebPIsAlphaMode(Wrapper.MODE_RGBA) != 0
        @test Wrapper.WebPIsAlphaMode(Wrapper.MODE_RGB) == 0
        @test Wrapper.WebPIsRGBMode(Wrapper.MODE_BGRA) != 0
        @test Wrapper.WebPIsRGBMode(Wrapper.MODE_YUV) == 0

        GC.@preserve static_data begin
            features = Ref{Wrapper.WebPBitstreamFeatures}()
            @test Wrapper.WebPGetFeatures(pointer(static_data), length(static_data), features) ==
                Wrapper.VP8_STATUS_OK
            @test features[].width == 1
            @test features[].height == 1
        end

        dec_buffer = Ref{Wrapper.WebPDecBuffer}()
        @test Wrapper.WebPInitDecBuffer(dec_buffer) != 0
        Wrapper.WebPFreeDecBuffer(dec_buffer)

        decoder_config = Ref{Wrapper.WebPDecoderConfig}()
        @test Wrapper.WebPInitDecoderConfig(decoder_config) != 0

        GC.@preserve static_data begin
            idec = Wrapper.WebPINewYUV(C_NULL, 0, 0, C_NULL, 0, 0, C_NULL, 0, 0)
            @test idec != C_NULL
            try
                @test Wrapper.WebPIAppend(idec, pointer(static_data), length(static_data)) ==
                    Wrapper.VP8_STATUS_OK
                last_y = Ref{Cint}()
                u = Ref{Ptr{UInt8}}()
                v = Ref{Ptr{UInt8}}()
                width = Ref{Cint}()
                height = Ref{Cint}()
                stride = Ref{Cint}()
                uv_stride = Ref{Cint}()
                @test Wrapper.WebPIDecGetYUV(
                    idec, last_y, u, v, width, height, stride, uv_stride
                ) != C_NULL
                @test width[] == 1
                @test height[] == 1
            finally
                Wrapper.WebPIDelete(idec)
            end
        end
    end

    @testset "Mux and demux helpers" begin
        mux = Wrapper.WebPMuxNew()
        @test mux != C_NULL
        Wrapper.WebPMuxDelete(mux)

        GC.@preserve static_data begin
            static_webp = Ref(Wrapper.WebPData(pointer(static_data), length(static_data)))
            mux = Wrapper.WebPMuxCreate(static_webp, 1)
            @test mux != C_NULL
            Wrapper.WebPMuxDelete(mux)
        end

        GC.@preserve animation_data begin
            animation_webp = Ref(
                Wrapper.WebPData(pointer(animation_data), length(animation_data))
            )
            demux = Wrapper.WebPDemux(animation_webp)
            @test demux != C_NULL
            @test Wrapper.WebPDemuxGetI(demux, Wrapper.WEBP_FF_FRAME_COUNT) == 1
            Wrapper.WebPDemuxDelete(demux)

            state = Ref{Wrapper.WebPDemuxState}(Wrapper.WEBP_DEMUX_PARSING_HEADER)
            demux = Wrapper.WebPDemuxPartial(animation_webp, state)
            @test demux != C_NULL
            @test state[] == Wrapper.WEBP_DEMUX_DONE
            Wrapper.WebPDemuxDelete(demux)
        end
    end

    @testset "Animation codec helpers" begin
        dec_options = Ref{Wrapper.WebPAnimDecoderOptions}()
        @test Wrapper.WebPAnimDecoderOptionsInit(dec_options) != 0

        GC.@preserve animation_data begin
            animation_webp = Ref(
                Wrapper.WebPData(pointer(animation_data), length(animation_data))
            )
            decoder = Wrapper.WebPAnimDecoderNew(animation_webp, dec_options)
            @test decoder != C_NULL
            Wrapper.WebPAnimDecoderDelete(decoder)
        end

        enc_options = Ref{Wrapper.WebPAnimEncoderOptions}()
        @test Wrapper.WebPAnimEncoderOptionsInit(enc_options) != 0

        encoder = Wrapper.WebPAnimEncoderNew(1, 1, enc_options)
        @test encoder != C_NULL
        Wrapper.WebPAnimEncoderDelete(encoder)
    end
end
