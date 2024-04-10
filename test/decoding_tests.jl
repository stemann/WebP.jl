using ColorTypes
using FixedPointNumbers
using Downloads
using Test
using WebP

@testset "Decoding" begin
    webp_galleries = (
        lossy = (
            url = "https://www.gstatic.com/webp/gallery",
            data = Dict(
                "1.webp" => (550, 368),
                "2.webp" => (550, 404),
                "3.webp" => (1280, 720),
                "4.webp" => (1024, 772),
                "5.webp" => (1024, 752),
            ),
        ),
        lossless = (
            url = "https://www.gstatic.com/webp/gallery3",
            data = Dict(
                "1_webp_ll.webp" => (400, 301),
                "2_webp_ll.webp" => (386, 395),
                "3_webp_ll.webp" => (800, 600),
                "4_webp_ll.webp" => (421, 163),
                "5_webp_ll.webp" => (300, 300),
            ),
        ),
    )
    for gallery in webp_galleries
        for (filename, image_size) in gallery.data
            mktempdir() do tmp_dir_path
                file_path = joinpath(tmp_dir_path, filename)
                Downloads.download(joinpath(gallery.url, filename), file_path)

                for kwargs in (NamedTuple(), (transpose = true,), (transpose = false,))
                    if hasproperty(kwargs, :transpose) && kwargs.transpose
                        expected_image_size = reverse(image_size)
                    else
                        expected_image_size = image_size
                    end

                    @testset "WebP.decode($(joinpath(gallery.url, filename)); $kwargs)" begin
                        image = WebP.decode(file_path; kwargs...)
                        @test size(image) == expected_image_size
                    end

                    for TColor in [ARGB{N0f8}, BGR{N0f8}, BGRA{N0f8}, RGB{N0f8}, RGBA{N0f8}, Gray{N0f8}]
                        @testset "WebP.decode($TColor, $(joinpath(gallery.url, filename)); $kwargs)" begin
                            image = WebP.decode(TColor, file_path; kwargs...)
                            @test size(image) == expected_image_size
                        end
                    end
                end
            end
        end
    end
end
