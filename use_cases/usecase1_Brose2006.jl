#=
Use case 1: Reproducing Brose et al., 2006 (fig. 2)
=#

using EcologicalNetworksDynamics
using EcologicalNetworks
using DataFrames

#= STEP 1: Generate variation in communities structure and properties
three structural food web models (cascade, niche and nested hierarchy)
three levels of diversity (20, 30, 40)
and eight bodymass ratios whose logs are evenly spaced from -2 to 5 
two metabolic categories (consumers are ecto. vertebrates, consumers are invertebrates)
=#

S_levels = [20, 30, 40] # species richness / initial diversity
models = [cascademodel, nichemodel, nestedhierarchymodel] # structural models
con = 0.15 # fixed connectance
Z_levels = 10 .^ [-2.0:1:5;] # average predator-prey mass ratio
metab_classes = ["ectotherm vertebrate", "invertebrate"]

#= Step 2: Generate the parameter sets
three functional responses (type II, type III, Beddington-DeAngelis)
=#

fr_types = [
    (h = 1.0, c = 0.0, type = "type II"),
    (h = 1.0, c = 1.0, type = "PI"),
    (h = 2.0, c = 0.0, type = "type III"),
]

# Create a data frame to store the outputs
df = []
global j = 0 # counter, just for visualizing progress
nsims =
    length(S_levels) *
    length(models) *
    length(Z_levels) *
    length(metab_classes) *
    length(fr_types)
for m in models
    for s in S_levels
        for z in Z_levels
            for c in metab_classes
                for f in fr_types
                    println(string(Symbol(m)) * ": S = $s ; Z = $(log10(z)) ; mc = $c")
                    fw = FoodWeb(m, s; C = con, Z = z, metabolic_class = c)
                    global j = j + 1
                    println("$j / $nsims")
                    # change the parameters of the functional response 
                    # (we want the original functional response, as defined in Yodzis and Ines original paper)
                    funcrep =
                        BioenergeticResponse(fw; hill_exponent = f.h, interference = f.c)
                    # generate the model parameters
                    p = ModelParameters(fw; functional_response = funcrep)

                    #= Step 3: Perform the simulations 
                    initial biomass (b0) are random
                    simulation last 3000 "time steps"
                    NB: some simulations may abort due to instabilities
                    =#
                    b0 = rand(richness(fw)) #initial biomass (random)
                    sim = simulate(p, b0; stop = 3000, use = :nonstiff)

                    if sim.t[end] == 3000.0
                        #= Step 4: Generate the outputs 
                        To reproduce fig 1, we need: 
                        - consumer-resource mass ratios
                        - consumers metabolic class
                        - initial diversity 
                        - type of model used to generate the food webs 
                        - type of the functional response 
                        - stability ("Population stability is the negative coefficient of variation of the persistent species", from Brose and al, 2006)
                        =#
                        ppmr = EcologicalNetworksDynamics.massratio(sim.ModelParameters)
                        z0 = z
                        out = (
                            z0 = log10(z0),
                            z = log10(ppmr),
                            mc = c,
                            s = s,
                            s_eq = sum(sim.B[end, :] .> 0),
                            mdl = string(Symbol(m)),
                            fr = f.type,
                            cv = EcologicalNetworksDynamics.population_stability(
                                sim;
                                last = 500,
                            ),
                        )
                        push!(df, out)
                    end
                end
            end
        end
    end
end

#= FIGURE 1
Population stability VS size structure for different scenarios of:
    - functional response 
    - diversity 
    - metabolic class
    - generative model
=#

df = DataFrame(df)
#remove collapsed food webs
df = df[df.s_eq.>0, :]

df.z .= round.(df.z)
using Plots, Statistics

clr = [:grey60, :black, :black]
lst = [:solid, :dash, :solid]
mks = [:rect, :rect, :dtriangle]

df1 = groupby(df, [:z0, :mdl])
meandf1 = combine(df1, :cv => mean)
plt1 = plot([NaN], [NaN]; label = "", leg = :bottomright)
for (i, m) in enumerate(string.(Symbol.(models)))
    tmp = meandf1[meandf1.mdl.==m, :]
    plot!(
        tmp.z0,
        tmp.cv_mean;
        ylims = (-1.2, 0.02),
        label = "$m",
        markershape = mks[i],
        mc = clr[i],
        msw = 0,
        linestyle = lst[i],
        lc = clr[i],
    )
end
plt1
xlabel!("log10(Z)")
ylabel!("Population stability")

df2 = groupby(df, [:z0, :s])
meandf2 = combine(df2, :cv => mean)
plt2 = plot([NaN], [NaN]; label = "", leg = :bottomright)
for (i, m) in enumerate(S_levels)
    tmp = meandf2[meandf2.s.==m, :]
    plot!(
        tmp.z0,
        tmp.cv_mean;
        ylims = (-1.2, 0.02),
        label = "$m species",
        markershape = mks[i],
        mc = clr[i],
        msw = 0,
        linestyle = lst[i],
        lc = clr[i],
    )
end
plt2
xlabel!("log10(Z)")
ylabel!("Population stability")

df3 = groupby(df, [:z0, :mc])
meandf3 = combine(df3, :cv => mean)
plt3 = plot([NaN], [NaN]; label = "", leg = :bottomright)
for (i, m) in enumerate(metab_classes)
    tmp = meandf3[meandf3.mc.==m, :]
    plot!(
        tmp.z0,
        tmp.cv_mean;
        ylims = (-1.2, 0.02),
        label = "$m",
        markershape = mks[i],
        mc = clr[i],
        msw = 0,
        linestyle = lst[i],
        lc = clr[i],
    )
end
plt3
xlabel!("log10(Z)")
ylabel!("Population stability")

df4 = groupby(df, [:z0, :fr])
meandf4 = combine(df4, :cv => mean)
plt4 = plot([NaN], [NaN]; label = "", leg = :bottomright)
for (i, m) in enumerate(unique(df.fr))
    tmp = meandf4[meandf4.fr.==m, :]
    plot!(
        tmp.z0,
        tmp.cv_mean;
        ylims = (-1.2, 0.02),
        label = "$m",
        markershape = mks[i],
        mc = clr[i],
        msw = 0,
        linestyle = lst[i],
        lc = clr[i],
    )
end
plt4
xlabel!("log10(Z)")
ylabel!("Population stability")

plot(plt4, plt2, plt3, plt1; size = (800, 600))
