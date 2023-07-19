module Doctest

using Documenter
import EcologicalNetworksDynamics

DocMeta.setdocmeta!(
    EcologicalNetworksDynamics,
    :DocTestSetup,
    :(using EcologicalNetworksDynamics);
    recursive = true,
)

doctest(EcologicalNetworksDynamics)

end
