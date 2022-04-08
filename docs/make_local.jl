using BEFWM2
using Documenter

# Use this temporary alternate file for local doc generation,
# so it does not interfere with github CI actions,
# for I'm not confident how it works within this repo yet.

DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive = true)

makedocs(;
    modules = [BEFWM2],
    authors =
    "Eva Delmas"
    * ", Hana Mayall"
    * ", Thomas Malpas"
    * ", Andrew Beckerman"
    * ", Ismaël Lajaaiti"
    * ", Iago Bonnici"
    * ", Sonia Kéfi",
    repo = "https://github.com/BecksLab/BEFWM2/blob/{commit}{path}#{line}",
    sitename = "BEFWM2.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
    ]
)
