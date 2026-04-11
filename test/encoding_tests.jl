using Test
using TestImages
using WebP

@testset "Encoding" begin
    kwargs_combos = (NamedTuple(), (transpose = true,), (transpose = false,))

    image_rgb = testimage("lighthouse")

    for TColor in [RGB, BGR, RGBA, BGRA]
        image = TColor.(image_rgb)

        for kwargs in kwargs_combos
            if hasproperty(kwargs, :transpose) && kwargs.transpose
                input_image = permutedims(image, (2, 1))
            else
                input_image = image
            end

            @testset "Lossless" begin
                @testset "WebP.encode(::Matrix{$TColor}; $kwargs)" begin
                    data = WebP.encode(input_image; kwargs...)
                    output = WebP.decode(data)
                    @test size(output) == size(image)
                end
            end

            @testset "Lossy" begin
                @testset "encode throws ArgumentError for quality outside range" begin
                    @test_throws ArgumentError WebP.encode(
                        input_image; lossy = true, quality = -1
                    )
                    @test_throws ArgumentError WebP.encode(
                        input_image; lossy = true, quality = 101
                    )
                end
                qualities = [1, 10, 50, 100]
                quality_types = [Int, Float32, Float64]
                for quality in qualities, TQuality in quality_types
                    input_kwargs = merge(
                        kwargs, (lossy = true, quality = TQuality(quality))
                    )
                    @testset "WebP.encode(::Matrix{$TColor}; $input_kwargs)" begin
                        data = WebP.encode(input_image; input_kwargs...)
                        output = WebP.decode(data)
                        @test size(output) == size(image)
                    end
                end
            end
        end
    end
end

@testset "Animated encoding" begin
    image_rgb = testimage("lighthouse")
    frame_stack_rgb = cat(image_rgb, reverse(image_rgb; dims = 2); dims = 3)
    frame_stack_rgba = RGBA.(frame_stack_rgb)

    @testset "Frame stack round-trip" begin
        for frame_stack in (frame_stack_rgb, frame_stack_rgba)
            data = WebP.encode(frame_stack; frame_duration_ms = 80)
            decoded_frames = WebP.decode(data; animated = true)
            typed_decoded_frames = WebP.decode(eltype(frame_stack), data; animated = true)
            decoded_animation = WebP.decode_animation(data)
            expected_default_frames = eltype(frame_stack) <: RGB ? RGBA.(frame_stack) : frame_stack

            @test size(decoded_frames) == size(frame_stack)
            @test decoded_frames == expected_default_frames
            @test typed_decoded_frames == frame_stack
            @test [frame.duration_ms for frame in decoded_animation.frames] == [80, 80]
            @test [frame.timestamp_ms for frame in decoded_animation.frames] == [80, 160]
        end
    end

    @testset "Animation round-trip" begin
        source_animation = WebP.decode_animation(
            WebP.encode(frame_stack_rgba; frame_duration_ms = 60, loop_count = 2)
        )
        data = WebP.encode(source_animation)
        decoded_animation = WebP.decode_animation(data)

        @test decoded_animation.canvas_size == source_animation.canvas_size
        @test decoded_animation.loop_count == source_animation.loop_count
        @test decoded_animation.background_color == source_animation.background_color
        @test [frame.timestamp_ms for frame in decoded_animation.frames] ==
            [frame.timestamp_ms for frame in source_animation.frames]
        @test [frame.duration_ms for frame in decoded_animation.frames] ==
            [frame.duration_ms for frame in source_animation.frames]
        @test map(frame -> frame.image, decoded_animation.frames) ==
            map(frame -> frame.image, source_animation.frames)
    end

    @testset "Animated write_webp" begin
        mktempdir() do tmp_dir_path
            file_path = joinpath(tmp_dir_path, "animated.webp")
            WebP.write_webp(file_path, frame_stack_rgb; frame_duration_ms = 90)
            decoded_animation = WebP.read_webp_animation(file_path)
            @test [frame.duration_ms for frame in decoded_animation.frames] == [90, 90]
            @test WebP.read_webp(file_path; animated = true) == RGBA.(frame_stack_rgb)
            @test WebP.read_webp(RGB{N0f8}, file_path; animated = true) == frame_stack_rgb

            animation = WebP.decode_animation(
                WebP.encode(frame_stack_rgba; frame_duration_ms = 70, loop_count = 1)
            )
            WebP.write_webp(file_path, animation)
            @test WebP.read_webp(file_path; animated = true) == frame_stack_rgba
        end
    end
end
