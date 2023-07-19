# The whole testing suite has been moved to "internals"
# while we are focusing on constructing the library API.

none_failed = true # Lower if any test fails.
include("./internals/runtests.jl")

if none_failed
    @info "Checking source code formatting.."
    exclude = [
        "README.md", # Not formatted according to JuliaFormatter.
        "CONTRIBUTING.md", # Not formatted according to JuliaFormatter.
        "docs/src/man/boost.md", # Wait on https://github.com/JuliaDocs/Documenter.jl/issues/2025 or the end of boost warnings.
    ]
    for (folder, _, files) in walkdir("..")
        for file in files
            path = joinpath(folder, file)
            display_path = joinpath(splitpath(path)[2:end]...)
            if display_path in exclude
                continue
            end
            if !any(endswith(file, ext) for ext in [".jl", ".md", ".jmd", ".qmd"])
                continue
            end
            println(display_path)
            if !format(path; overwrite = false, format_markdown = true)
                config_path =
                    joinpath(basename(dirname(abspath(".."))), ".JuliaFormatter.toml")
                dev_path = escape_string(abspath(path))
                @warn "Source code in $file is not formatted according \
                to the project style defined in $config_path. \
                Consider formatting it using your editor's autoformatter or with:\n\
                    julia> using JuliaFormatter;\n\
                    julia> format(\"$dev_path\", format_markdown=true)\n"
            end
        end
    end
end
