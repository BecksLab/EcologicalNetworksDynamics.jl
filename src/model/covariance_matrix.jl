"""
A script to create the matrix of constant covariance (Γ, Gamma) needed for a CorrelatedWienerProcess
The user supplies a matrix with dimensions that match number of stochastic species, which I think I want allocated in the bottom right
And then I autogenerate 0s and an identity matrix (of size stochspecies? or richness(FW)?)

First we create a correlation matrix
Then we pre-multiply and post-multiply by a matrix with the sigma values as the diagonal
"""

# Matrix needs to be of size richness(FW) + stochspecies

"""
There are several rules the correlation matrix needs to follow. It can be broken up into 4 parts
    1. It has to be positive definite!
    2. Top-left is an identity matrix of size richness(FW) - this relates to the lack of correlation (and subsequent covariance) allowed between noise governing demographic stochasticity
    3. Top-right is a matrix of zeros of size stochspecies x richness(FW)
    4. Bottom-left is a matrix of zeros of size richness(FW) x stochspecies. These two parts relate to the correlation between environmental and demographic stochastic noise processes - of which there is none
    5. Bottom right is a matrix relating to correlation between environmental stochasticity. The principle diagonal is made up from 1s, all other elements can be anything -1 < x < 1 (default to 0)
"""

function correlation_matrix(
    FW::FoodWeb,
    AS::AddStochasticity,
    corrmat::Union{Matrix{Float64},Nothing} = nothing,
)
    if isnothing(corrmat)
        corrmat = I(length(AS.stochspecies))
    elseif size(corrmat, 1) != size(corrmat, 2)
        throw(ArgumentError("Please provide a square matrix"))
    elseif size(corrmat, 1) > length(AS.stochspecies)
        scorrmat = size(corrmat, 1)
        ls = length(AS.stochspecies)
        @warn "Matrix provided is $scorrmat x $scorrmat but there are only $ls stochastic species. \n Trimming matrix to size"
        corrmat = corrmat[1:length(AS.stochspecies), 1:length(AS.stochspecies)]
    elseif size(corrmat, 1) < length(AS.stochspecies)
        ls = length(AS.stochspecies)
        throw(
            ArgumentError("The provided matrix is not big enough (needs to be $ls x $ls)"),
        )
    end

    for i in corrmat
        if i > 1.0 || i < -1.0
            throw(
                ArgumentError(
                    "All elements in the correlation matrix must be between -1 and 1",
                ),
            )
        end
    end

    for i in 1:size(corrmat, 1)
        if corrmat[i, i] != 1
            @warn "All values of the principle diagonal need to be 1.0. Replacing other values with 1.0"
            corrmat[i, i] = 1
        end
    end

    @assert issuccess(bunchkaufman(Γ, check = false)) == false "Correlation matrix needs to be positive semidefinite"
    @assert any(eigvals(Γ) .< 0) == false "Correlation matrix needs to be positive semidefinite"

    demographic_stochasticity_component = hcat(I(richness(FW)), zeros(richness(FW), length(AS.stochspecies)))
    environmental_stochasticity_component = hcat(zeros(length(AS.stochspecies), richness(FW)), corrmat)
    rmat = vcat(demographic_stochasticity_component, environmental_stochasticity_component)

    return (rmat)
end

"""
A covariance matrix is created from a correlation matrix by pre- and post-multiplying it by a matrix with the principle diagonal containing the standard deviations

In the AddStochasticity object, stochspecies contains all the positional information and σd and σe the relevant standard deviations
We just need to create a matrix using this information
"""

function sd_matrix(FW::FoodWeb, AS::AddStochasticity)
    sdmat = zeros(
        richness(FW) + length(AS.stochspecies),
        richness(FW) + length(AS.stochspecies),
    )
    for i in eachindex(AS.stochspecies)
        sdmat[richness(FW)+i, richness(FW)+i] = AS.σe[i]
    end
    for i in 1:richness(FW)
        sdmat[i, i] = AS.σd[i]
    end
    return sdmat
end

"""
Finally, put the two together

This final function just needs a FoodWeb object, an AddStochasticity object, and optionally a correlation matrix
Returns the covariance matrix.
"""

function cov_matrix(
    FW::FoodWeb,
    AS::AddStochasticity,
    corrmat::Union{Matrix{Float64},Nothing} = nothing,
)
    sdmat = sd_matrix(FW, AS)
    rmat = correlation_matrix(FW, AS, corrmat)
    covmat = sdmat * rmat * sdmat
    return covmat
end
