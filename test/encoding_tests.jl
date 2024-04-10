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
                qualities = [1, 10, 50, 100]
                for quality in qualities
                    input_kwargs = merge(kwargs, (quality = quality,))
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
