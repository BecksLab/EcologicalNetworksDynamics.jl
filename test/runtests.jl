using Documenter
using BEFWM2
using Test

# Run doctests first.
DocMeta.setdocmeta!(BEFWM2, :DocTestSetup, :(using BEFWM2); recursive = true)
doctest(BEFWM2)

@testset "BEFWM2.jl" begin
    # A few dummy tests to check test system.
    @test 1 == 1 #  should pass.
    @test 1 == 2 #  should fail.
end
