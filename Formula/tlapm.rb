class Tlapm < Formula
  desc "TLA+ Proof Manager"
  homepage "https://github.com/tlaplus/tlapm"
  url "https://github.com/tlaplus/tlapm/archive/9a52fafb00245ace0877ec8d91c4a09a7caa8061.tar.gz"
  version "1.6.0-pre.20261118180108"
  sha256 "84e6c920db01b827c0d81b95a6531ef9a0a69f963dc39d43fb8c6ba12ea8a5fc"
  license "BSD-2-Clause"

  livecheck do
    skip "The tap tracks the commit tagged by the upstream rolling pre-release"
  end

  depends_on "gawk" => :build
  depends_on "ocaml" => :build
  depends_on "opam" => :build
  depends_on "perl" => :build
  depends_on "pkgconf" => :build
  depends_on "unzip" => :build
  depends_on "wget" => :build
  # Upstream's bundled Z3 build for Linux targets x86-64.
  depends_on arch: :x86_64
  depends_on :linux
  depends_on "gmp"
  depends_on "zlib"

  allow_network_access! :build

  def install
    ENV["OPAMROOT"] = buildpath/".opam"
    ENV["OPAMYES"] = "1"
    ENV["OPAMJOBS"] = ENV.make_jobs.to_s
    system "opam", "init", "--compiler=ocaml-system", "--disable-sandboxing", "--no-setup"
    system "opam", "install", "./tlapm.opam", "--deps-only", "--no-depexts"

    # Source archives lack the Git metadata Dune normally uses for --version.
    inreplace "dune-project", "(name tlapm)\n\n(generate_opam_files true)",
              "(name tlapm)\n(version #{version})\n\n(generate_opam_files true)"
    # Isabelle and Isabelle-test share an extraction recipe that must run serially.
    inreplace "deps/isabelle/dune", '(run "make" "-f" "dune.mk")', '(run "make" "-j1" "-f" "dune.mk")'
    system "opam", "exec", "--", "dune", "build", "@install", "-j", ENV.make_jobs.to_s
    system "opam", "exec", "--", "dune", "install", "--relocatable", "--prefix", libexec
    bin.install_symlink libexec/"bin/tlapm"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tlapm --version")
    (testpath/"Smoke.tla").write <<~TLA
      ---- MODULE Smoke ----
      EXTENDS Naturals, TLAPS
      THEOREM TwoPlusTwo == 2 + 2 = 4
      BY Z3
      ====
    TLA
    system bin/"tlapm", "Smoke.tla"
  end
end
