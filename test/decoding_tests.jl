using Base64
using ColorTypes
using FixedPointNumbers
using Downloads
using Test
using WebP

@testset "Decoding" begin
    download_available = true
    webp_galleries = (
        lossy = (
            url = "https://www.gstatic.com/webp/gallery",
            data = Dict(
                "1.webp" => (368, 550),
                "2.webp" => (404, 550),
                "3.webp" => (720, 1280),
                "4.webp" => (772, 1024),
                "5.webp" => (752, 1024),
            ),
        ),
        lossless = (
            url = "https://www.gstatic.com/webp/gallery3",
            data = Dict(
                "1_webp_ll.webp" => (301, 400),
                "2_webp_ll.webp" => (395, 386),
                "3_webp_ll.webp" => (600, 800),
                "4_webp_ll.webp" => (163, 421),
                "5_webp_ll.webp" => (300, 300),
            ),
        ),
    )
    for gallery in webp_galleries
        for (filename, image_size) in gallery.data
            mktempdir() do tmp_dir_path
                file_path = joinpath(tmp_dir_path, filename)
                try
                    Downloads.download(joinpath(gallery.url, filename), file_path)
                catch err
                    if err isa Downloads.RequestError
                        download_available = false
                        @info "Skipping remote decoding fixture because download failed" url=joinpath(
                            gallery.url, filename
                        ) error=sprint(showerror, err)
                        return
                    end
                    rethrow()
                end

                for kwargs in (NamedTuple(), (transpose = true,), (transpose = false,))
                    if hasproperty(kwargs, :transpose) && kwargs.transpose
                        expected_image_size = reverse(image_size)
                    else
                        expected_image_size = image_size
                    end

                    @testset "WebP.read_webp($(joinpath(gallery.url, filename)); $kwargs)" begin
                        image = WebP.read_webp(file_path; kwargs...)
                        @test size(image) == expected_image_size
                    end

                    for TColor in [
                        ARGB{N0f8}, BGR{N0f8}, BGRA{N0f8}, RGB{N0f8}, RGBA{N0f8}, Gray{N0f8}
                    ]
                        @testset "WebP.read_webp($TColor, $(joinpath(gallery.url, filename)); $kwargs)" begin
                            image = WebP.read_webp(TColor, file_path; kwargs...)
                            @test size(image) == expected_image_size
                        end
                    end
                end
            end
        end
    end
    download_available || @test_skip download_available
end

@testset "Animated decoding" begin
    faq_feature_images = (
        lossy = "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA",
        animation = "UklGRlIAAABXRUJQVlA4WAoAAAASAAAAAAAAAAAAQU5JTQYAAAD/////AABBTk1GJgAAAAAAAAAAAAAAAAAAAGQAAABWUDhMDQAAAC8AAAAQBxAREYiI/gcA",
    )

    animation_data = base64decode(faq_feature_images.animation)
    expected_frame_timestamps = [100]
    expected_frame_durations = [100]
    expected_background_color = 0xffffffff
    expected_loop_count = 0

    for kwargs in (NamedTuple(), (transpose = true,), (transpose = false,))
        @testset "WebP.decode(::Vector{UInt8}; animated = true, $kwargs)" begin
            frames = WebP.decode(animation_data; animated = true, kwargs...)
            @test size(frames) == (1, 1, 1)
            @test frames[:, :, 1] == fill(RGBA{N0f8}(0, 0, 0, 0), size(frames)[1:2])
        end

        for TColor in [
            ARGB{N0f8}, BGR{N0f8}, BGRA{N0f8}, RGB{N0f8}, RGBA{N0f8}, Gray{N0f8}
        ]
            @testset "WebP.decode($TColor, ::Vector{UInt8}; animated = true, $kwargs)" begin
                frames = WebP.decode(TColor, animation_data; animated = true, kwargs...)
                @test size(frames) == (1, 1, 1)
                @test eltype(frames) == TColor
            end
        end
    end

    @testset "WebP.decode_animation" begin
        animation = WebP.decode_animation(animation_data)
        @test length(animation.frames) == 1
        @test animation.canvas_size == size(first(animation.frames).image)
        @test [frame.timestamp_ms for frame in animation.frames] == expected_frame_timestamps
        @test [frame.duration_ms for frame in animation.frames] == expected_frame_durations
        @test animation.loop_count == expected_loop_count
        @test animation.background_color == expected_background_color
        @test first(animation.frames).image == fill(RGBA{N0f8}(0, 0, 0, 0), animation.canvas_size)
    end

    @test_throws ArgumentError WebP.decode(
        base64decode(faq_feature_images.lossy); animated = true
    )
    @test_throws ArgumentError WebP.decode_animation(base64decode(faq_feature_images.lossy))

    mktempdir() do tmp_dir_path
        file_path = joinpath(tmp_dir_path, "animated.webp")
        write(file_path, animation_data)
        frames = WebP.read_webp(file_path; animated = true)
        @test size(frames) == (1, 1, 1)

        animation = WebP.read_webp_animation(file_path)
        @test length(animation.frames) == 1
        @test animation.canvas_size == size(first(animation.frames).image)
        @test [frame.timestamp_ms for frame in animation.frames] == expected_frame_timestamps
        @test [frame.duration_ms for frame in animation.frames] == expected_frame_durations
    end
end
