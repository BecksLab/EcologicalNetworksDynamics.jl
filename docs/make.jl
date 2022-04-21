using BEFWM2
using Documenter

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
    repo = "https://github.com/ilajaait/BEFWM2/blob/{commit}{path}#{line}",
    sitename = "BEFWM2.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo = "github.com/ilajaait/BEFWM2",
    devbranch = "doc"
)
