# Homebrew tap for TLAPM

Build the TLA⁺ Proof Manager from the latest upstream rolling pre-release commit on x86-64 Linux. The formula uses Homebrew's OCaml compiler and upstream's build rules for the proof backends. [Upstream releases](https://github.com/tlaplus/tlapm/releases)

## Install

```sh
brew install andrelucas/tlapm/tlapm
tlapm --version
tlapm --config
```

The installation compiles TLAPM and downloads its OCaml dependencies and prover inputs, including the roughly 1 GB Isabelle distribution. The source build was tested on Rocky Linux 9 with system glibc 2.34 and Homebrew's glibc 2.39 runtime.

For editors that need a TLA⁺ library path, use `$(brew --prefix tlapm)/libexec/lib/tlapm/stdlib`.

## Upgrade

```sh
brew update
brew upgrade tlapm
```

Each formula version includes the rolling commit's UTC timestamp. The tap checks the upstream tag hourly and pins the exact source archive and its SHA-256 checksum. The workflow builds the candidate and checks a proof with Z3 before publishing an update.

## Maintain the tap

Host this repository as `andrelucas/homebrew-tlapm` on GitHub and enable Actions. The **TLAPM tap** workflow can also be run manually from the default branch. Its publish job uses GitHub's built-in token to push the tested formula update to that branch.

From a local clone, run `python3 scripts/update-formula.py` to refresh the formula, then commit the result. On a supported Linux host, test the committed formula with `brew tap local/tlapm "$PWD"`, `brew install local/tlapm/tlapm`, and `brew test local/tlapm/tlapm`.
