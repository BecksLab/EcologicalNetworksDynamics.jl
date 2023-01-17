using BEFWM2
using Documenter

DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive = true)

makedocs(;
    modules = [BEFWM2],
    authors = "Eva Delmas" *
              ", Ismaël Lajaaiti" *
              ", Thomas Malpas" *
              ", Hana Mayall" *
              ", Iago Bonnici" *
              ", Sonia Kéfi" *
              ", Andrew Beckerman",
    repo = "https://github.com/BecksLab/BEFWM2/blob/{commit}{path}#{line}",
    sitename = "BEFWM2.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Generate food webs" => "man/foodwebs.md",
            "Generate multiplex networks" => "man/multiplexnetworks.md",
            "Generate model parameters" => "man/modelparameters.md",
            "Choose a functional reponse" => "man/functionalresponse.md",
            "Run simulations" => "man/simulations.md",
            "Boost simulations" => "man/boost.md",
            "Measure stability" => "man/stability.md",
        ],
        "Examples" => [
            "Paradox of enrichment" => "example/paradox_enrichment.md",
            "Intraspecific competition and stability" => "example/intracomp_stability.md",
        ],
        "Library" => ["Public" => "lib/public.md", "Internals" => "lib/internals.md"],
    ],
)

deploydocs(; repo = "github.com/BecksLab/BEFWM2.jl.git", devbranch = "doc")
