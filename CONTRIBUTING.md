# Contribution guidelines

You are willing to contribute to BEFWM2 project
and edit the source code. Thank you <3  
This small guide is supposed to help you through the installation process
as a developer instead of a simple user,
and introduce a typical developping workflow
so you can be comfortable contributing.

This guide assumes you're working on a standard linux distribution
and makes use of basic shell commands
and [Julia's REPL].
If you are not and you have trouble following along,
don't hesitate to reach out at [BecksLab/BEFWM2]
and ask for support.

[BecksLab/BEFWM2]: https://github.com/BecksLab/BEFWM2
[Julia's REPL]: https://docs.julialang.org/en/v1/stdlib/REPL/

## Set up a clean working directory to host the project

The package sources are essentially contained
within one folder named `BEFWM2/`,
that you can freely __(1)__ __navigate and edit to contribute__.
When you are done, you will likely want to
__(2)__ __try your modifications__ out
with some personal examples and toy scripts.
This is how you can decide that you are happy with your contribution.

Regarding __(2)__,
we advise against working directly in the source directory.
Instead, use another directory like `BEFWM2_sandbox/` or `BEFWM2-dev/`.
This gives you full latitude to use custom IDE configurations there,
generate figures *etc.* without polluting the sources.

### 1. Create your development directory

Make yourself at home with:

```console
$ mkdir BEFWM2-dev
$ cd BEFWM2-dev
```

### 2. Clone BEFWM2 sources

Download latest state of the project with:

```console
$ git clone git@github.com:BecksLab/BEFWM2.git
```

At this point, your directories structure should look something like:

```
BEFWM2-dev/
├── BEFWM2/
│   ├── .git/
│   ├── README.md
│   ├── CONTRIBUTING.md
│   ├── Project.toml
│   ├── ...
```

### 3. Setting up your development environment

Julia works with distincts [environments].
Any folder can become a Julia environment
provided it contains correct `Project.toml` and `Manifest.toml` files.

[environments]: https://pkgdocs.julialang.org/v1/environments/

Now you want to add the package to your development environment.
Enter Julia REPL first with:

```sh
$ julia --project=.
```

Then, from the REPL:

```julia
julia> ]                      # Just type ']' key at the prompt.
(BEFWM2-dev) pkg> dev BEFWM2/ # Add BEFWM2 as a dev-dependency.
(BEFWM2-dev) pkg> add Revise  # Track sources modifications.
(BEFWM2-dev) pkg> update      # This takes a while the first time.
```

[`Revise`] is very useful to not to have to re-load `BEFWM2` package manually
after every modification and restart your development session.

[`Revise`]: https://timholy.github.io/Revise.jl/stable/

At this point, you should be able to use the package from this environment.
To verify it, create the following toy script:

```
BEFWM2-dev/
├── sandbox.jl     <- "toy script"
├── Project.toml   <- (automatically created during `dev` and `add` commands)
├── Manifest.toml  <- (automatically created during `update` command)
├── BEFWM2/
│   ├── ...
```

In `sandbox.jl`:
```julia
using Revise
using BEFWM2

# Dummy use of the package just to try it out.
foodweb = FoodWeb([0 0; 1 0])

println("Good.")
```

If you can successfully run it with:

```console
$ julia --project=. sandbox.jl
```

Then your initial setup is successful.


### 4. Setup/Refresh BEFWM2 source directory

At this point you can use and modify the package,
but you cannot generate documentation, run the tests or the benchmarks yet.

This section explains how to correctly set up the source `BEFWM2/` directory.
It is also useful if you feel like you have messed up everything
and you wish to reset this folder to a clean state.

#### Clean up whole sources folder

The following needs to happen at the root source folder `./BEFWM2`:

```console
$ cd path/to/BEFWM2/
```

Delete every file not tracked by git, including `Manifest.toml` files.  
Beware that this will permanently delete any file not yet commited.

```console
$ git reset --hard      # Unstage all non-commited files
$ git checkout develop  # (or any branch you are willing to work on)
$ git clean -xdf        # Delete all non-staged files.
```

#### Setup source projects environments.

The file `BEFWM2/Manifest.toml` needs to be re-generated
with latest version of dependencies.

```console
$ julia --project=.
julia> ]
(BEFWM2) pkg> update   # (precompilation does take a while the first time)
```

While standing in this `(BEFWM2) pkg>` package mode,
take this opportunity to set up tests, documentation and benchmark environments:
```julia
(BEFWM2) pkg> activate test  # Switch to `BEFWM2/test` environment.
(test) pkg> update           # Re-generate `BEFWM2/test/Manifest.toml`.

(test) pkg> activate docs    # Switch to `BEFWM2/docs` environment.
(docs) pkg> dev .            # add `BEFWM2` as a dev-dependency to `BEFWM2/docs`
(docs) pkg> update           # Re-generate `BEFWM2/docs/Manifest.toml`.

(docs) pkg> activate bench   # Switch to `BEFWM2/bench` environment.
(bench) pkg> dev .           # add `BEFWM2` as a dev-dependency to `BEFWM2/bench`
(bench) pkg> update          # Re-generate `BEFWM2/bench/Manifest.toml`.
```

The whole source project is now ready to go.


## Run the tests and generate the package documentation

You have modified existing functions
and you wish to ensure that you have not broken anything.
Alternately, you have written new functions
and added new tests to the `BEFWM2/test` folder
or in doctests strings.
In any case, you can run all tests with:

```console
$ cd path/to/BEFWM2
$ julia --project=.
julia> ]
(BEFWM2) pkg> test  # Run all tests in docstrings and `test/` folder.
```

### Generate and read the documentation

You need to read the latest source documentation on current branch,
or you have written new docstrings, documentation pages in `BEFWM2/docs/src/`
and you would like to check what they look like.
Generate all documentation with:

```console
$ cd path/to/BEFWM2/docs
$ julia --project=. make.jl   # (fails if doctests fail)
```

Documentation is generated in `BEFWM2/docs/build/` folder.
Browse with any web browser, like for instance:

```console
$ firefox build/index.html
```

## Work with git

### Basic workflow

Before working on your contribution,
make sure you do so on a dedicated branch, for instance with:

```console
$ git checkout develop             # Most common branch to base your work upon.
$ git checkout -b my_cool_feature  # Create your branch and switch to it.
```

Construct your successive commits as usual with.

```console
$ git add modified_or_new_files
$ git commit
```

When your feature is ready,
open a pull request with your branch on the official repo.
Your code will be reviewed there before it is eventually merged into `develop`.


### Keep your work downstream the `develop` branch

BEFWM2 enforces linear git history with a rebase strategy.
As a consequence, as you are working on your branch,
it sometimes happens that `develop` moves forward in another direction.
This is not a problem and you can keep going until your pull request is ready.

However, if you need to integrate
the latest `develop` features into your branch,
please *refrain* from introducing merge commits with commands like:

```console
$ # git merge develop  # This complicates enforcement of git rebase strategy !
```

Instead, rebase your branch onto the new `develop` location with commands like:
```console
$ git rebase develop  # You will be prompted for any conflict resolution then.
```
or, more explicitly:
```console
$ git rebase --ont develop my_cool_feature
```

Should you wish not to loose your original history before rebasing your branch,
you can create personal tags prior to rebase, for instance with:
```console
$ git tag -a my_safety_tag -m "The commit I was standing on before I rebased."
```

To check that everything went well, use either
```console
$ git log --decorate --oneline --graph --all --color
```
or your prefered git client / software / IDE extension.

Once your branch has been correctly rebased,
it is okay to submit it by force-pushing it to the main repo:
```console
$ git push --force origin my_cool_feature
```

__Don't hesitate to reach out to [BecksLab/BEFWM2]
in case you need any sort of kind help or support.__
__Happy contributing <3__


