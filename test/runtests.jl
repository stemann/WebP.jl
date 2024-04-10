using Test

@testset "WebP.jl" begin
    include(joinpath(@__DIR__, "decoding_tests.jl"))
end
