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
            "Generate food webs" => joinpath("man", "foodwebs.md"),
            "Generate multiplex networks" => joinpath("man", "multiplexnetworks.md"),
            "Generate model parameters" => joinpath("man", "modelparameters.md"),
            "Choose a functional reponse" => joinpath("man", "functionalresponse.md"),
            "Run simulations" => joinpath("man", "simulations.md"),
            "Measure stability" => joinpath("man", "stability.md"),
        ],
        "Examples" => [
            "Paradox of enrichment" => joinpath("example", "paradox_enrichment.md"),
            "Intraspecific competition and stability" =>
                joinpath("example", "intracomp_stability.md"),
        ],
        "Library" => [
            "Public" => joinpath("lib", "public.md"),
            "Internals" => joinpath("lib", "internals.md"),
        ],
    ],
)

deploydocs(; repo = "github.com/BecksLab/BEFWM2.jl.git", devbranch = "doc")
