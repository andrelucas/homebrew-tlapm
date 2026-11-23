# Homebrew tap for TLAPM

Install the TLA⁺ Proof Manager (`tlapm`) on x86-64 and ARM64 Linux. Homebrew builds it from the upstream rolling pre-release. [Upstream releases](https://github.com/tlaplus/tlapm/releases)

## Install

```sh
brew install andrelucas/tlapm/tlapm
tlapm --version
tlapm --config
```

Homebrew selects the prebuilt bottle for your architecture when one is available. Both bottles are built on Ubuntu 24.04 and also run on Rocky Linux 9 with system glibc 2.34 and Homebrew's glibc 2.39 runtime.

On minimal Linux images, install `ps` from `procps` on Ubuntu or `procps-ng` on Rocky Linux.

Building from source requires fontconfig and an installed font for Isabelle. It downloads OCaml dependencies and prover inputs, including the roughly 1 GB Isabelle distribution.

For editors that need a TLA⁺ library path, use `$(brew --prefix tlapm)/libexec/lib/tlapm/stdlib`.

## Install with mise

With mise 2026.11.12 or later, install the bottle for your Linux architecture with one command.

```sh
mise bootstrap packages apply brew:andrelucas/tlapm/tlapm
/home/linuxbrew/.linuxbrew/bin/tlapm --version
```

For a project or machine bootstrap, add the following package to `mise.toml` and run `mise bootstrap packages apply --manager brew`.

```toml
[bootstrap.packages]
"brew:andrelucas/tlapm/tlapm" = "latest"
```

## Upgrade

```sh
brew update
brew upgrade tlapm
```

The tap checks for upstream updates hourly. Each package version includes the upstream commit's UTC timestamp.
