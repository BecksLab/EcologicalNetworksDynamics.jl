### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ bf8c3229-66ba-4047-8555-8d9301f54c59
import Pkg

# ╔═╡ 0b2f1ec9-502f-406e-8606-b1429ee68f9c
Pkg.activate("../")

# ╔═╡ 78bf2904-c529-44d8-9207-6f3b7e1b0477
using BEFWM2

# ╔═╡ f4e082f5-95bf-4dc3-9b14-ade08d87bac7
using PlutoUI

# ╔═╡ 57848f7b-d4d8-42c4-b4ab-e639131f78c8
using Mangal

# ╔═╡ 8a097e9d-9ccb-4d28-830d-afb0b0640300
using Plots

# ╔═╡ 597bfe88-2bd7-4c71-b5a2-33c417ad3d11
using EcologicalNetworks

# ╔═╡ 2ec1202a-69cf-4779-8feb-5302d837dab0
html"<button onclick='present()'>present</button>"

# ╔═╡ fb80a042-eeeb-467f-8be7-c32e048b3638
struct Foldable{C}
    title::String
    content::C
end

# ╔═╡ 7ef5c3d3-aae8-4e06-ae70-35d4b74fece2
function Base.show(io, mime::MIME"text/html", fld::Foldable)
    write(io,"<details><summary>$(fld.title)</summary><p>")
    show(io, mime, fld.content)
    write(io,"</p></details>")
end

# ╔═╡ ba6c073b-30e3-4c81-93f6-29e3c729b2e3
struct TwoColumn{L, R}
    left::L
    right::R
end

# ╔═╡ 64b8ccbb-540c-4361-bbd5-c62bec74065a
function Base.show(io, mime::MIME"text/html", tc::TwoColumn)
    write(io, """<div style="display: flex;"><div style="flex: 50%;">""")
    show(io, mime, tc.left)
    write(io, """</div><div style="flex: 50%;">""")
    show(io, mime, tc.right)
    write(io, """</div></div>""")
end

# ╔═╡ 3400b7de-b545-47f4-a778-fbc4292edda9
import Random.seed!

# ╔═╡ 1394ee67-edff-47ea-a126-6a44f54c775c
seed!(22)

# ╔═╡ 9d022c9e-3bee-11ec-23c5-6fa7e4ece9a1
md"""
# BioEnergieticFoodWebs V2.0: easier and faster?

Eva Delmas, Nov. 10, 2021. 

Refactoring of the `BioEnergeticFoodWebs.jl` package.
"""

# ╔═╡ 6ef129f5-a27e-4a3c-b3ff-c9212e0e23ef
md"""
## Why refactor BEFWM? 

- One function `model_parameters()` controlling too many modules behaviour 
  - core component (community structure and species traits), biological rates, functional response, rewiring, effect of temperature, nutrient intake model, etc. Each comes with many possibilities and their own set of parameters.
- Too complicated to be consistently tested 
- Too slow / too memory hungry
- Not compatible with the rest of EcoJulia (`Mangal`, `EcologicalNetworks`, etc)
"""

# ╔═╡ 34bf416e-dc97-416c-97d0-a9555adf9754
md"""
## Simplified?

BEFWM is still based on a `ModelParameters` function with a default behavior, but this function is actually built around 5 core objects (modules) instead of 50 unorganized parameters: 
- `FoodWeb`
- `BioRates`
- `Environment`
- `FunctionalResponse`
- `Rewiring`
"""

# ╔═╡ ca50e4a9-359a-4506-a946-7177100ff9ad
TwoColumn(md""" $(LocalResource("modules_befwm1.png")) """, md""" $(LocalResource("modules_befwm2.png")) """)

# ╔═╡ f4445127-bf56-425d-b1dd-44041e97803c
TwoColumn(html""" <center>BEFWM v.1 </center> """, html""" <center>BEFWM v.2 </center> """)

# ╔═╡ 04f487c3-594c-4138-8b3d-98374f2d4aa6
md"""
1 "module" = 1 object $\rightarrow$ 1 corresponding function (generate the object) that can have multiple method

Objects $\rightarrow$ make it easier to implement specific test 
"""

# ╔═╡ 5d3e9dcb-b2f3-4fdf-96ec-3780ec78d5c4
md"""
## `FoodWeb`
"""

# ╔═╡ ec82b536-a8a9-41d0-8667-c11a09f445aa
md"""
**Basic input: the community food web.**

Different methods for generating food webs, all return an object of type `FoodWeb` with 5 fields:
- `A` sparse array of boolean values representing the adjacency matrix, with consumers as rows (`i`) and resources in columns (`j`). `A[i,j] = true` if species `i` eats species `j`;
- `species`: vector describing species identities
- `M`: vector of species body mass
- `metabolic_class`: vector describing species metabolic class
- `method` described the method used to build the food web. This is especially useful when using a model (e.g. `nichemodel` from `EcologicalNetworks`) because method will then take automatically take the name of the model, but this can be used to store any information abou the food web (e.g. the source if it is an empirical food web).
"""

# ╔═╡ c5b569fe-bb5a-4999-8407-e4fd46091725
md"""
## `FoodWeb`
"""

# ╔═╡ 576c0953-b3c4-433f-80e3-a9931b986ad6
A = [0 1 0 ; 0 0 1 ; 0 0 0] #linear food chain

# ╔═╡ 5d0fe4ea-bfd9-4ab9-bc72-c25417fcc3e5
fw = FoodWeb(A)

# ╔═╡ a572e335-6430-469a-ae30-66fb80f5a351
typeof(fw)

# ╔═╡ 13a0ff82-242c-4689-bb4c-a4c94432dd8a
fieldnames(FoodWeb)

# ╔═╡ fbabe6d7-d689-4e3c-a92e-2a136b0deea0
md"## `FoodWeb`"

# ╔═╡ cf5f7913-271f-4bf9-87ab-f4323313c37f
fw.A

# ╔═╡ 9ae9ab0a-4435-4464-b6c5-3f3cecea1829
fw.species

# ╔═╡ 7fb712ae-2900-4f68-b48a-9c7811db2117
fw.M

# ╔═╡ 07b60baf-2260-4e4e-b4af-f30caced48df
fw.metabolic_class

# ╔═╡ 90722148-ebb2-4317-9b50-d54789be9152
fw.method

# ╔═╡ cecac699-623a-4402-a519-7f54867c8b28
md"""
## `FoodWeb`: compatible with `EcologicalNetworks`
"""

# ╔═╡ 6728993f-c61f-43e2-9937-954378304df8
md"Use the generative food web models from `EcologicalNetworks`:"

# ╔═╡ 087c709d-2c9a-4d56-a25a-7bc417e1c3f5
fw_niche = FoodWeb(nichemodel, 10, C = 0.2)

# ╔═╡ 2e6f135a-c720-4bdb-8312-609d564c7fd1
fw_niche.method

# ╔═╡ fa793db5-630a-4bf0-9e0c-4ca7467837b0
N = convert(UnipartiteNetwork, fw_niche)

# ╔═╡ 8e82b42e-703d-4e63-8007-993cc11ab9b3
fw_niche2 = FoodWeb(N)

# ╔═╡ 2396c1a3-6f1e-45ed-9d34-96b2423570ed
fw_cascade = FoodWeb(cascademodel, 20, C = 0.15)

# ╔═╡ c4a18605-6fca-4d3d-9c09-35c59f9a94cd
md"Use the methods from `EcologicalNetworks`:"

# ╔═╡ 9116e3bb-2bca-45c8-a280-e3085717c67d
richness(fw_niche)

# ╔═╡ a8130448-3796-4fa8-b19f-403c4f91694c
md"Or convert directly to a `UnipartiteNetwork` object to take full advantage of `EcologicalNetworks`:"

# ╔═╡ 2e7f3c8b-f103-4226-85c8-7d24fbb425bb
degree(N)

# ╔═╡ 159710fd-1899-4552-a474-b80c40e221c9
md"## `FoodWeb`: species mass"

# ╔═╡ 1c10c335-1ba7-4e2b-ac77-80beeae416af
md"Modify species mass by passing a vector of mass or a consumer-resource mass ratio."

# ╔═╡ aea56578-974e-4f1b-8bad-18dfd8b9f879
fw_z = FoodWeb(A, Z = 10)

# ╔═╡ 18270383-afd8-412b-b8ce-2d56c47bf7ee
fw_z.M

# ╔═╡ f85846d2-318f-43c2-a0c1-cb0d523ba842
fw_m = FoodWeb(A, M = [12.43, 7.3, 1.9])

# ╔═╡ 3231b6a8-96ca-4c73-a0df-d87b8b90ca83
fw_m.M

# ╔═╡ e2d34b1e-ea0e-49f3-87eb-64ed70d10a1b
md"## `FoodWeb`: metabolic class"

# ╔═╡ b97c56c6-3e0c-47e3-92db-1591ad8540bd
A2 = [
 0  0  0  0  0  ;
 0  0  0  0  0  ;
 1  1  0  0  0  ;
 0  0  1  0  0  ;
 0  0  1  1  0  
]

# ╔═╡ c8c388eb-596d-454f-875d-a4bdf386f727
metab = ["producer", "producer", "invertebrate", "ectotherm vertebrate", "ectotherm vertebrate"]

# ╔═╡ 56ac9f8e-f196-4d0f-a8a6-be1d10c70e6b
fw_mc = FoodWeb(A2, metabolic_class = metab)

# ╔═╡ e5ecc542-5212-463d-b03b-a5d4c6e1ca1b
metab[2] = "invertebrate"

# ╔═╡ a32ff3b4-fd81-4a0d-b320-7a3d36282af5
fw_mcwrg = FoodWeb(A2, metabolic_class = metab)

# ╔═╡ 067ab6e6-4bc1-4f76-aa3c-2f2d15c84f8e
md"""` Warning: You provided a metabolic class for basal species - replaced by producer @BEFWM2 ~/projets/BEFWM2/src/inputs/foodwebs.jl:28`"""

# ╔═╡ f7619ae6-2b5a-4590-820d-01b1bb076fb0
fw_mcwrg.metabolic_class[2]

# ╔═╡ 6e30c4d2-2a0f-4b2e-bb8e-9a3bbd537ae7
md"## `ModelParameters`"

# ╔═╡ 94498c6a-7770-45ae-a0ed-934c6fe2383f
mp =  ModelParameters(fw) #model parameters for the linear 3-species food chain

# ╔═╡ 82448e7e-b359-475f-912b-d64b29cfe6cf
md"""
Note that only the `FoodWeb` has to be explicitwely passed, default methods generates the other objects: 
- `BioRates`
- `Environment`
- `FunctionalResponse`
- 🚧 `Rewiring` 🚧
"""

# ╔═╡ 69e83a05-3253-4a01-b4e1-05f69e9f6521
md"## `BioRates`"

# ╔═╡ 41ab8b44-1f67-4b69-94a0-f41224c02009
md"One of the most important feature of the bioenergetic model is the allometric scaling of the biological rates."

# ╔═╡ fbd10d44-a3d6-4cc0-bc1e-616d940648d9
md"Default: Allometric scaling as in Brose et al., 2006"

# ╔═╡ 1ab36496-39da-4549-b7c1-c3be3fd045ea
mp.BioRates

# ╔═╡ f08fa774-6395-4d93-837b-b99b5e631135
br = BioRates(fw)

# ╔═╡ 6a77bd3c-ba6e-4d2f-8519-acff37f6dad2
typeof(br)

# ╔═╡ 893b17d5-52ee-4f66-b01a-414fd09bb371
fieldnames(BioRates)

# ╔═╡ fa519130-edee-418f-a290-181cc5959eac
br.r #intrinsic growth rate 

# ╔═╡ c4d7945b-f12f-4e1c-ab14-b97683070eea
br.x #metabolic rate

# ╔═╡ bdbe9343-05a4-4957-9f19-d47eea0aa337
br.y #maximum consumption rate

# ╔═╡ 00c22209-3d91-4a2a-b669-fdea44787565
md"## `BioRates`"

# ╔═╡ 093d2c86-5d1c-48ce-8b1f-7eea589f92de
md"Each biological rate can be controlled individually, by changing the method used and the corresponding parameters:"

# ╔═╡ 8bb78900-d0bd-44c3-9b5d-f5965ac06911
r = allometricgrowth(fw_mc, a = 0.5, b = -0.2) #change the constant and the exponent, same for all producers

# ╔═╡ 9936d56b-0770-447a-a287-033a74c6bfc1
x = allometricmetabolism(fw_mc, b_p = -0.25, b_ect = -0.3, b_inv = -0.3) #p: producers, ect: ectotherm vertebrates, inv: invertebrates. Pass different exponents for each

# ╔═╡ 0f5baf53-a7f1-4830-97c6-844414414e2e
y = fill(8.0, richness(fw_mc))

# ╔═╡ b9bd28a1-a87e-403d-96e7-c0e00784510e
br_spe = BioRates(fw_mc, r = r, x = x, y = y)

# ╔═╡ 7f150ee1-351b-4e37-86b3-f1342150c37e
br_spe2 = BioRates(fw_mc, rmodel = allometricgrowth, rparameters = (a = 0.5,))

# ╔═╡ 5381f9eb-ae6f-4070-bf7d-babc583d8f0f
md"## `FunctionalResponse`"

# ╔═╡ 4358c5ad-341a-46f4-851d-73ef228fca89
md"""
2 main types of implementation for the functional response. 
- One uses the consumers maximum assimilation rates and half saturation densities -- as described in the original description of the model by Yodzis and Innes (1992) 
- the other, more classical formulation, relies on pairwise attack rates and handling times (not implemented yet, work in progress)."""

# ╔═╡ 43b56d15-6372-4b69-9326-b9e93ef6e2d5
mp.FunctionalResponse

# ╔═╡ 468c3536-eccd-4d07-aaee-f79efd395c60
funcrep = originalFR(fw_mc)

# ╔═╡ 9e27c8f7-8269-42b8-8bc9-5048592a856a
typeof(funcrep)

# ╔═╡ 508fca1e-b921-4922-b778-1e94856e5cde
fieldnames(FunctionalResponse)

# ╔═╡ ce679432-9394-40f7-bdaf-e4d3313ea37b
md"## `FunctionalResponse`"

# ╔═╡ 2c704a3b-43ac-4bd3-a759-483a04ad1c66
funcrep.functional_response

# ╔═╡ 46110a91-2ffc-4eaf-92fd-22d61730ba81
md"""
$FR_{ij} = \frac {\omega_{ij}B_{j}^{h}}{B_{0}^{h}+c_iB_iB_{0}^{h}+\sum_{k=resources} \omega_{ik} B_{k}^{h}}$
"""

# ╔═╡ 276c3ab2-265c-454d-95f2-a5bd4906bb0f
funcrep.hill_exponent

# ╔═╡ 83939544-1630-42ff-b76b-d08f45df3f4e
funcrep.c

# ╔═╡ 9cc133bc-ab3f-4209-ae6d-79d2c96ec459
funcrep.e

# ╔═╡ 6bc5d8d2-abd4-4d9a-b4b6-c16899db3d1d
funcrep.B0

# ╔═╡ f4b053ed-31ca-47e9-bfe1-4d88a3193151
funcrep.ω

# ╔═╡ 1a6989c3-ede5-4273-9907-2e07b70d495a
md"## `Environment`"

# ╔═╡ 9b06dbe7-f3a6-4097-aa4b-c9c8977a49b9
mp.Environment

# ╔═╡ 5b5f6e70-2a0a-44dc-937c-d81c3436bb3f
md"""
Still a work in progress, only `K` is used now (for calculating the net growth rate).  

🚧 Temperature will be important when `BioRates` sets the functions for calculating certains rates to `boltzmann`.
"""

# ╔═╡ ea684766-290b-4347-b01d-7475e44a5f6f
md"## Quick example"

# ╔═╡ 62347e6f-0697-473e-8f67-ea9e21838e30
#using Mangal, EcologicalNetworks

# ╔═╡ 9c09d8a8-5913-42dd-ba96-25bb8db81198
md"Retrieve data from Mangal"

# ╔═╡ d7a858ec-813f-4330-bb13-5fa753c1a1ed
benguela = datasets("q" => "Benguela")[1]

# ╔═╡ 19d47851-4aa9-4fa1-ab58-351a007abacb
benguela_n = networks(benguela, "count" => 1)[1]

# ╔═╡ 21da8aa4-2e77-40e0-8845-20293c03b22e
N_benguela = convert(UnipartiteNetwork, benguela_n)

# ╔═╡ dca9ae61-3878-4294-850b-afef25270415
fw_benguela = FoodWeb(N_benguela)

# ╔═╡ 15210dff-5dda-4704-a70f-e75a8be4b15c
fw_benguela.species

# ╔═╡ 49bcbbf0-5bde-44eb-a751-842270f0d0ac
md"## Quick example"

# ╔═╡ 45e966ad-3ee1-467d-9c92-48d8a25d369b
Env = Environment(fw_benguela, K = 10)

# ╔═╡ 71f1594e-a94c-426e-8046-d318ad8f509a
p = ModelParameters(fw_benguela, E = Env)

# ╔═╡ b1663b39-4040-4d2b-9e31-f70854799fae
b_init = rand(richness(fw_benguela))

# ╔═╡ 258a7cec-e624-4bdb-b7f7-e74890a87ff6
sim = simulate(p, b_init, stop = 500, use = :nonstiff)

# ╔═╡ 687476f8-710c-4915-8471-71db46c501e1
md"## Quick example"

# ╔═╡ 4143616c-ad28-491e-aa46-27fd4c5d0c00
sp_order = sortperm(sim.B[end,:], rev = true)

# ╔═╡ beebd888-d289-4c27-9433-839787224e4c
spnames_ord = fw_benguela.species[sp_order]

# ╔═╡ e7cb3275-1538-431f-b51f-010e193d3e2e
plot(sim.t, sim.B[:,sp_order], labels = permutedims(spnames_ord), legend = :outertopright, xlabel = "time (relative)", ylabel = "species biomass", size = (750,450))

# ╔═╡ 357ad23b-6f1a-445e-8b1c-c67112897a35


# ╔═╡ Cell order:
# ╟─2ec1202a-69cf-4779-8feb-5302d837dab0
# ╟─bf8c3229-66ba-4047-8555-8d9301f54c59
# ╟─0b2f1ec9-502f-406e-8606-b1429ee68f9c
# ╟─78bf2904-c529-44d8-9207-6f3b7e1b0477
# ╟─f4e082f5-95bf-4dc3-9b14-ade08d87bac7
# ╟─57848f7b-d4d8-42c4-b4ab-e639131f78c8
# ╟─8a097e9d-9ccb-4d28-830d-afb0b0640300
# ╟─fb80a042-eeeb-467f-8be7-c32e048b3638
# ╟─7ef5c3d3-aae8-4e06-ae70-35d4b74fece2
# ╟─ba6c073b-30e3-4c81-93f6-29e3c729b2e3
# ╟─64b8ccbb-540c-4361-bbd5-c62bec74065a
# ╟─3400b7de-b545-47f4-a778-fbc4292edda9
# ╟─1394ee67-edff-47ea-a126-6a44f54c775c
# ╟─9d022c9e-3bee-11ec-23c5-6fa7e4ece9a1
# ╟─6ef129f5-a27e-4a3c-b3ff-c9212e0e23ef
# ╟─34bf416e-dc97-416c-97d0-a9555adf9754
# ╟─ca50e4a9-359a-4506-a946-7177100ff9ad
# ╟─f4445127-bf56-425d-b1dd-44041e97803c
# ╟─04f487c3-594c-4138-8b3d-98374f2d4aa6
# ╟─5d3e9dcb-b2f3-4fdf-96ec-3780ec78d5c4
# ╟─ec82b536-a8a9-41d0-8667-c11a09f445aa
# ╟─c5b569fe-bb5a-4999-8407-e4fd46091725
# ╠═576c0953-b3c4-433f-80e3-a9931b986ad6
# ╠═5d0fe4ea-bfd9-4ab9-bc72-c25417fcc3e5
# ╠═a572e335-6430-469a-ae30-66fb80f5a351
# ╠═13a0ff82-242c-4689-bb4c-a4c94432dd8a
# ╟─fbabe6d7-d689-4e3c-a92e-2a136b0deea0
# ╠═cf5f7913-271f-4bf9-87ab-f4323313c37f
# ╠═9ae9ab0a-4435-4464-b6c5-3f3cecea1829
# ╠═7fb712ae-2900-4f68-b48a-9c7811db2117
# ╠═07b60baf-2260-4e4e-b4af-f30caced48df
# ╠═90722148-ebb2-4317-9b50-d54789be9152
# ╟─cecac699-623a-4402-a519-7f54867c8b28
# ╠═597bfe88-2bd7-4c71-b5a2-33c417ad3d11
# ╟─6728993f-c61f-43e2-9937-954378304df8
# ╠═2396c1a3-6f1e-45ed-9d34-96b2423570ed
# ╠═087c709d-2c9a-4d56-a25a-7bc417e1c3f5
# ╠═2e6f135a-c720-4bdb-8312-609d564c7fd1
# ╠═fa793db5-630a-4bf0-9e0c-4ca7467837b0
# ╠═8e82b42e-703d-4e63-8007-993cc11ab9b3
# ╟─c4a18605-6fca-4d3d-9c09-35c59f9a94cd
# ╠═9116e3bb-2bca-45c8-a280-e3085717c67d
# ╟─a8130448-3796-4fa8-b19f-403c4f91694c
# ╠═2e7f3c8b-f103-4226-85c8-7d24fbb425bb
# ╟─159710fd-1899-4552-a474-b80c40e221c9
# ╟─1c10c335-1ba7-4e2b-ac77-80beeae416af
# ╠═aea56578-974e-4f1b-8bad-18dfd8b9f879
# ╠═18270383-afd8-412b-b8ce-2d56c47bf7ee
# ╠═f85846d2-318f-43c2-a0c1-cb0d523ba842
# ╠═3231b6a8-96ca-4c73-a0df-d87b8b90ca83
# ╟─e2d34b1e-ea0e-49f3-87eb-64ed70d10a1b
# ╟─b97c56c6-3e0c-47e3-92db-1591ad8540bd
# ╟─c8c388eb-596d-454f-875d-a4bdf386f727
# ╠═56ac9f8e-f196-4d0f-a8a6-be1d10c70e6b
# ╠═e5ecc542-5212-463d-b03b-a5d4c6e1ca1b
# ╠═a32ff3b4-fd81-4a0d-b320-7a3d36282af5
# ╟─067ab6e6-4bc1-4f76-aa3c-2f2d15c84f8e
# ╠═f7619ae6-2b5a-4590-820d-01b1bb076fb0
# ╟─6e30c4d2-2a0f-4b2e-bb8e-9a3bbd537ae7
# ╠═94498c6a-7770-45ae-a0ed-934c6fe2383f
# ╟─82448e7e-b359-475f-912b-d64b29cfe6cf
# ╟─69e83a05-3253-4a01-b4e1-05f69e9f6521
# ╟─41ab8b44-1f67-4b69-94a0-f41224c02009
# ╟─fbd10d44-a3d6-4cc0-bc1e-616d940648d9
# ╠═1ab36496-39da-4549-b7c1-c3be3fd045ea
# ╠═f08fa774-6395-4d93-837b-b99b5e631135
# ╠═6a77bd3c-ba6e-4d2f-8519-acff37f6dad2
# ╠═893b17d5-52ee-4f66-b01a-414fd09bb371
# ╠═fa519130-edee-418f-a290-181cc5959eac
# ╠═c4d7945b-f12f-4e1c-ab14-b97683070eea
# ╠═bdbe9343-05a4-4957-9f19-d47eea0aa337
# ╟─00c22209-3d91-4a2a-b669-fdea44787565
# ╟─093d2c86-5d1c-48ce-8b1f-7eea589f92de
# ╠═8bb78900-d0bd-44c3-9b5d-f5965ac06911
# ╠═9936d56b-0770-447a-a287-033a74c6bfc1
# ╠═0f5baf53-a7f1-4830-97c6-844414414e2e
# ╠═b9bd28a1-a87e-403d-96e7-c0e00784510e
# ╠═7f150ee1-351b-4e37-86b3-f1342150c37e
# ╟─5381f9eb-ae6f-4070-bf7d-babc583d8f0f
# ╟─4358c5ad-341a-46f4-851d-73ef228fca89
# ╠═43b56d15-6372-4b69-9326-b9e93ef6e2d5
# ╠═468c3536-eccd-4d07-aaee-f79efd395c60
# ╠═9e27c8f7-8269-42b8-8bc9-5048592a856a
# ╠═508fca1e-b921-4922-b778-1e94856e5cde
# ╟─ce679432-9394-40f7-bdaf-e4d3313ea37b
# ╠═2c704a3b-43ac-4bd3-a759-483a04ad1c66
# ╟─46110a91-2ffc-4eaf-92fd-22d61730ba81
# ╠═276c3ab2-265c-454d-95f2-a5bd4906bb0f
# ╠═83939544-1630-42ff-b76b-d08f45df3f4e
# ╠═9cc133bc-ab3f-4209-ae6d-79d2c96ec459
# ╠═6bc5d8d2-abd4-4d9a-b4b6-c16899db3d1d
# ╠═f4b053ed-31ca-47e9-bfe1-4d88a3193151
# ╟─1a6989c3-ede5-4273-9907-2e07b70d495a
# ╠═9b06dbe7-f3a6-4097-aa4b-c9c8977a49b9
# ╟─5b5f6e70-2a0a-44dc-937c-d81c3436bb3f
# ╟─ea684766-290b-4347-b01d-7475e44a5f6f
# ╠═62347e6f-0697-473e-8f67-ea9e21838e30
# ╟─9c09d8a8-5913-42dd-ba96-25bb8db81198
# ╠═d7a858ec-813f-4330-bb13-5fa753c1a1ed
# ╠═19d47851-4aa9-4fa1-ab58-351a007abacb
# ╠═21da8aa4-2e77-40e0-8845-20293c03b22e
# ╠═dca9ae61-3878-4294-850b-afef25270415
# ╠═15210dff-5dda-4704-a70f-e75a8be4b15c
# ╟─49bcbbf0-5bde-44eb-a751-842270f0d0ac
# ╠═45e966ad-3ee1-467d-9c92-48d8a25d369b
# ╠═71f1594e-a94c-426e-8046-d318ad8f509a
# ╠═b1663b39-4040-4d2b-9e31-f70854799fae
# ╠═258a7cec-e624-4bdb-b7f7-e74890a87ff6
# ╟─687476f8-710c-4915-8471-71db46c501e1
# ╠═4143616c-ad28-491e-aa46-27fd4c5d0c00
# ╠═beebd888-d289-4c27-9433-839787224e4c
# ╠═e7cb3275-1538-431f-b51f-010e193d3e2e
# ╠═357ad23b-6f1a-445e-8b1c-c67112897a35
