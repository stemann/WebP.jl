using FileIO
using Test
using TestImages
using WebP

@testset "FileIO interface" begin
    expected_image = testimage("lighthouse")

    mktempdir() do tmp_dir_path
        file_path = joinpath(tmp_dir_path, "lighthouse.webp")
        f = File{format"WebP"}(file_path)
        WebP.write_webp(file_path, expected_image)

        @testset "fileio_load" begin
            image = WebP.fileio_load(f)
            @test size(image) == size(expected_image)
        end

        @testset "fileio_save" begin
            WebP.fileio_save(f, expected_image)
            image = WebP.read_webp(file_path)
            @test size(image) == size(expected_image)
        end
    end
end
