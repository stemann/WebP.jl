using Clang.Generators
using libwebp_jll

include(joinpath(@__DIR__, "HeaderOnlyWrapperGeneration", "HeaderOnlyWrapperGeneration.jl"))
using .HeaderOnlyWrapperGeneration

cd(@__DIR__)

include_dir = joinpath(libwebp_jll.artifact_dir, "include", "webp")

generator_toml_path = joinpath(@__DIR__, "generator.toml")
header_only_wrappers_path = joinpath(@__DIR__, "header_only_wrappers_epilogue.jl")

args = get_default_args()
push!(args, "-I$include_dir")

headers = [
    joinpath(include_dir, header) for
    header in readdir(include_dir) if endswith(header, ".h")
]

discovered_header_only_wrappers = discover_header_only_wrapper_names(headers, args)
validate_header_only_wrapper_configuration(discovered_header_only_wrappers)
write_header_only_wrapper_file(header_only_wrappers_path, discovered_header_only_wrappers)

options = load_options(generator_toml_path)
options["general"]["output_ignorelist"] = discovered_header_only_wrappers

ctx = create_context(headers, args, options)

build!(ctx)
