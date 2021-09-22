# The functional response 

~~~julia-repl
julia> #define a food web
julia> using EcologicalNetworks
julia> fw = FoodWeb(nichemodel, 20, C = 0.2, Z = 10)
20 species - 61 links. 
 Method: nichemodel
julia> #define the functional response
julia> fr = originalFR(dfw) #default values
functional response: classical
type III
julia> #check the parameter values
julia> fr.functional_response #is the function that will be used internally by the model
(::BEFWM2.var"#classical#11") (generic function with 1 method)
julia> fr.B0 #is the half saturation density
0.5
julia> fr.ω #describes consumers relative preferences for their resources
20×20 SparseMatrixCSC{Float64, Int64} with 64 stored entries:
⠤⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠰⠦⠀⠀⠀⠀⠀⠀⠀⠀
⠘⠻⢭⣁⣀⣀⡀⠀⠀⠀
⠄⢀⣀⣀⣐⣚⡓⠒⠂⠀
⠀⠄⠀⠀⣀⡀⠛⠛⠉⠉
julia> fr.hill_exponent #shape of the functional response 
2.0
julia> fr.c #predator interference
20-element Vector{Real}:
 0.0
 0.0
 0.0
 0.0
 ⋮
 0.0
 0.0
 0.0
~~~

## Change the parameter values 

All parameters can be changed 

~~~julia-repl
julia> fr = originalFR(fw, B0 = rand(length(fw.species)), interference = 1.0, hill_exponent = 1.2) 
~~~