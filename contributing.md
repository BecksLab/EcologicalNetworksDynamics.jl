# Contribution guidelines

## Set a clean working directory to code (opiniated guidelines)

We detail in the following how to set up a clean working to develop.

### 1. Clone BEFWM2

```bash
git clone git@github.com:BecksLab/BEFWM2.git
```

### 2. Create a directory for development

We advise against working directly in the directory of the package.
Working from another directory, dedicated to that purpose,
allows you to freely generate trash files (e.g. figures)
that would pollute the package
if working directly from the package directory.

```bash
mkdir BEFWM2-dev
```

At this step you should have something like that:

```
├── BEFWM2-dev
├── BEFWM2
```

Now you want to add the package to your dev environment.

```bash
cd ../BEFWM2-dev # go to your dev directory
julia --project=.
```

```julia
julia> ]
(BEFWM2-dev) pkg> dev ./BEFWM2/
(BEFWM2-dev) pkg> add Revise # allow to reload the package after modification
(BEFWM2-dev) pkg> update     # can take a while
```

`Revise` directly updates the package if you modify it
without having to restart your development directory.
For more information, see [Revise.jl](https://timholy.github.io/Revise.jl/stable/).

### 3. Clean BEFWM2 and subdirectories

#### Clean `BEFWM2` main directory

```bash
cd BEFWM2
git checkout develop
git reset --hard     # forget about any uncommited changes
git clean -xdf       # get rid of any untracked files like Manifest.toml etc.
julia --project=.    # enter julia within root environment
```

```julia
julia> ]               # enter package mode
(BEFWM2) pkg> update   # re-create up-to-date Manifest.toml, precompile everything (yeah, 'takes a while)
```

#### Clean `test` directory

```bash
cd BEFWM2/test
julia --project=.
```

```julia
julia> ]
(test) pkg> update  # this should take less time since everything has already been precompiled on upper level.
```

#### Clean `docs` directory

```bash
cd ../docs
julia --project=.
```

```julia
julia> ]
(docs) pkg> dev ..   # add BEFWM2 as a dev-dependency.
(docs) pkg> update
```

## Run the tests and generate the package documentation

### Run the tests

```bash
cd path/to/BEFWM2
julia --project=.
```

```julia
julia> ]
(BEFWM2) pkg> test
```

### Generate and read the documentation

```bash
cd docs
julia --project=. make.jl
```

At this step the documentation should be built,
to read it you can for instance open the generated `.html` files with firefox
(or any other web browser).

```bash
firefox build/index.html
```

## Routine for package updates

### Run the tests

If you modify the package, the first to do is to ensure that the tests still pass.

```bash
cd path/to/BEFWM2
julia --project=.
```

```jl
julia> ]
(BEFWM2) pkg> test
```

If the test displays warnings about formatting,
you can fix them with:

```julia
using JuliaFormatter
format_file("/path/the/file")
```

### Build the documentation

```bash
cd docs
julia --project=. make.jl # build
firefox build/index.html  # read
```

### Rebase your git branch on the `develop` branch

Keep your dev history before rebase by putting a tag on your last commit.

```bash
cd path/to/BEFWM2
git checkout my_branch
git tag -a v.xx -m "my version xx"
```

Rebase your branch (i.e. your commit chain) on top of develop/

```bash
git rebase --onto develop my_branch
```

Check the results.

```bash
git log --decorate --oneline --graph --all --color
```

Push the new state of your branch (sitted on top of develop) to github:

```bash
git push --force origin mybranch
```
