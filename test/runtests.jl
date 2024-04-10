using Test

@testset "WebP.jl" begin
    include(joinpath(@__DIR__, "decoding_tests.jl"))
    include(joinpath(@__DIR__, "encoding_tests.jl"))
end
