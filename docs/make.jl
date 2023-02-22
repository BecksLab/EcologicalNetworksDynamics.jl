using EcologicalNetworksDynamics
using Documenter

DocMeta.setdocmeta!(
    EcologicalNetworksDynamics,
    :DocTestSetup,
    :(using EcologicalNetworksDynamics);
    recursive = true,
)

makedocs(;
    modules = [EcologicalNetworksDynamics],
    authors = "Eva Delmas" *
              ", Ismaël Lajaaiti" *
              ", Thomas Malpas" *
              ", Hana Mayall" *
              ", Iago Bonnici" *
              ", Sonia Kéfi" *
              ", Andrew Beckerman",
    repo = "https://github.com/BecksLab/EcologicalNetworksDynamics.jl/blob/{commit}{path}#{line}",
    sitename = "EcologicalNetworksDynamics.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[],
    ),
    pages = [
        "Welcome" => "index.md",
        "Guide" => [
            "Quick start" => "man/quickstart.md",
            "Generate food webs" => "man/foodwebs.md",
            "Generate multiplex networks" => "man/multiplexnetworks.md",
            "Generate model parameters" => "man/modelparameters.md",
            "Choose a functional reponse" => "man/functionalresponse.md",
            "Run simulations" => "man/simulations.md",
            "Boost simulations" => "man/boost.md",
            "Measure stability" => "man/stability.md",
        ],
        "Tutorials" => [
            "Paradox of enrichment" => "example/paradox_enrichment.md",
            "Intraspecific competition and stability" => "example/intracomp_stability.md",
        ],
        "Library" => ["Public" => "lib/public.md", "Internals" => "lib/internals.md"],
    ],
)

deploydocs(; repo = "github.com/BecksLab/EcologicalNetworksDynamics.jl", devbranch = "doc")
