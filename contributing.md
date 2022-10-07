- Based on exchanges with Iago

# Set a clean working directory to code (opiniated guidelines)


- Clone BEFWM2: 

```bash
git clone git@github.com:BecksLab/BEFWM2.git
```

- Create a dev directory:

```bash
mkdir befw2_dev
```

- Now you will have something like that: 

```
├── befwm2_dev
├── BEFWM2
```

- Clean BEFWM2:

```
$ cd BEFWM2
$ git checkout develop 
$ git reset --hard     # forget about any uncommited changes
$ git clean -xdf       # get rid of any untracked files like Manifest.toml etc.
$ julia --project=.    # enter julia within root environment
julia> ]               # enter package mode
(BEFWM2) pkg> update   # re-create up-to-date Manifest.toml, precompile everything (yeah, 'takes a while)
```


- Set your dev environment:

```
$ cd ../befwm2_dev # Go to your dev directory 
$ julia --project=.
```

```jl
add Pkg
Pkg.dev("./BEFWM2/")
Pkg.add("Revise") # Allow to reload the package after modification (e.g. `using Revise`) 
Pkg.update() # Take a long time
```

- Now in tests:

```
$ cd BEFWM2/test
$ julia --project=.
julia> ]
(test) pkg> update  # this should take less time since everything has already been precompiled on upper level.
```

- Now in doc:

```
$ cd ../docs
$ julia --project=.
julia> ]
(docs) pkg> dev ..   # Add BEFWM2 as a dev-dependency.
(docs) pkg> update
```

- Run the test of the package:

```
$ cd path/to/BEFWM2
$ julia --project=.
julia> ]
(BEFWM2) pkg> test
```

- Generate and read the doc: 

```
$ cd docs
$ julia --project=. make.jl
$ firefox build/index.html
```

# Routine for package updates

## Run test

```bash
$ cd path/to/BEFWM2
$ julia --project=.
```

```jl
julia> ]
(BEFWM2) pkg> test
```

If the test displays warnings about formatting,
you can fix them by:

```
using JuliaFormatter
format_file("/path/the/file")
```


## Build the doc
```bash
$ cd docs
$ julia --project=. make.jl
$ firefox build/index.html
```

## Rebase your git branch on `develop` branch 

- Keep your dev history before rebase by putting a tag on your last commit

```
$ cd path/to/BEFWM2
$ git checkout my_branch
$ git tag -a v.xx -m "my version xx"
```

- Rebase your branch (i.e. your commit chain) on top of develop: 
```
$ git rebase --onto develop my_branch

```

- Check the results:

```
$ git log --decorate --oneline --graph --all --color
```

- Push the new state of your branch (sitted on top of develop) to github:

```
$ git push --force origin mybranch
```


