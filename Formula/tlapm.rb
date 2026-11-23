class Tlapm < Formula
  POLYML_DIR = "lib/tlapm/backends/Isabelle-install/poly".freeze
  POLYML_EXECUTABLES = %w[poly polyimport].freeze

  desc "TLA+ Proof Manager"
  homepage "https://github.com/tlaplus/tlapm"
  url "https://github.com/tlaplus/tlapm/archive/961e909fa3aca1fba412ee0908c5848b808e4b24.tar.gz"
  version "1.6.0-pre.20261120174017"
  sha256 "6a664c060bddcba87b85c9708d11a31ee4483c0646787fa80ac940d59830f3f9"
  license "BSD-2-Clause"

  livecheck do
    skip "The tap tracks the commit tagged by the upstream rolling pre-release"
  end

  bottle do
    root_url "https://github.com/andrelucas/homebrew-tlapm/releases/download/tlapm-1.6.0-pre.20261120174017-45171268982-1"
    rebuild 2
    sha256 arm64_linux:  "eac200665fbeb651005e43089f8c631d002cca0e619a4e647e6ea47b78b497e2"
    sha256 x86_64_linux: "52d6a3c6edd384f9e3a337ad7810834eb5fbf05d346283519f62e8ba054d5c32"
  end

  depends_on "gawk" => :build
  depends_on "ocaml" => :build
  depends_on "opam" => :build
  depends_on "perl" => :build
  depends_on "pkgconf" => :build
  depends_on "unzip" => :build
  depends_on "wget" => :build
  depends_on :linux
  depends_on "gmp"
  depends_on "zlib"

  on_intel do
    depends_on "patchelf" => :build
  end

  on_arm do
    depends_on "cmake" => :build
    depends_on "python@3.14" => :build

    resource "z3" do
      url "https://github.com/Z3Prover/z3/archive/refs/tags/z3-4.8.9.tar.gz"
      sha256 "c9fd04b9b33be74fffaac3ec2bc2c320d1a4cc32e395203c55126b12a14ff3f4"
    end
  end

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
    if Hardware::CPU.arm?
      inreplace "deps/isabelle/dune.mk" do |s|
        s.gsub! "$(ISABELLE_VSN)_linux.tar.gz", "$(ISABELLE_VSN)_linux_arm.tar.gz"
        s.gsub! "3d1d66de371823fe31aa8ae66638f73575bac244f00b31aee1dcb62f38147c56",
                "a7f1e9fbb279809cb9b3a0550f931ad4cbb6392e7723c052ee0292398601d0f1"
      end

      # LS4's x87 precision adjustment only applies to x86.
      Pathname("deps/ls4/ls4.patch").open("a") do |patch|
        patch.write <<~PATCH
          --- ls4-1.0.orig/core/Main.cc
          +++ ls4-1.0/core/Main.cc
          @@ -853,2 +853,2 @@
          -#if defined(__linux__)
          +#if defined(__linux__) && (defined(__i386__) || defined(__x86_64__))
                   fpu_control_t oldcw, newcw;
        PATCH
      end
      # LS4 stores EOF in a char, which GCC treats as unsigned by default on ARM.
      inreplace "deps/ls4/Makefile", "make -C $(LS4_BASE_NAME)/core",
                "make -C $(LS4_BASE_NAME)/core COPTIMIZE='-O3 -fsigned-char'"

      # Upstream ships Z3 4.8.9 for x86-64 Linux. Build the same release for ARM64.
      resource("z3").stage do
        # The API generator imports distutils, which Python 3.12 removed.
        inreplace "scripts/mk_util.py" do |s|
          s.gsub! "import distutils.sysconfig", "import sysconfig"
          s.gsub! 'distutils.sysconfig.get_python_lib(prefix=getenv("PREFIX", None))',
                  'sysconfig.get_path("purelib", vars={"base": getenv("PREFIX", sys.prefix)})'
          s.gsub! "distutils.sysconfig.get_python_lib()", 'sysconfig.get_path("purelib")'
          s.gsub! "distutils.sysconfig.get_python_version()", "sysconfig.get_python_version()"
        end
        system "cmake", "-S", ".", "-B", "build", *std_cmake_args,
               "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
               "-DPYTHON_EXECUTABLE=#{Formula["python@3.14"].opt_bin}/python3.14"
        system "cmake", "--build", "build", "--target", "shell", "--parallel", ENV.make_jobs.to_s
        cp "build/z3", buildpath/"deps/z3/native-z3"
        pkgshare.install "LICENSE.txt" => "Z3-LICENSE.txt"
      end
      inreplace "deps/z3/dune" do |s|
        s.gsub! '(deps "Makefile")', '(deps "native-z3")'
        s.gsub! '(run "make" "-C" "." "z3")', '(copy "native-z3" "z3")'
      end
    end

    system "opam", "exec", "--", "dune", "build", "@install", "-j", ENV.make_jobs.to_s
    system "opam", "exec", "--", "dune", "install", "--relocatable", "--prefix", libexec
    bin.install_symlink libexec/"bin/tlapm"

    if Hardware::CPU.intel?
      # Preserve Poly/ML through bottle relocation and unpack it after the pour.
      rpath = ["$ORIGIN", HOMEBREW_PREFIX/"opt/gcc/lib/gcc/current",
               HOMEBREW_PREFIX/"opt/glibc/lib", HOMEBREW_PREFIX/"lib"].join(":")
      POLYML_EXECUTABLES.each do |name|
        executable = libexec/POLYML_DIR/name
        system "patchelf", "--set-interpreter", HOMEBREW_PREFIX/"lib/ld.so",
               "--force-rpath", "--set-rpath", rpath, executable
        system "/usr/bin/gzip", "-n", executable
      end
    end
  end

  post_install_steps do
    POLYML_EXECUTABLES.each do |name|
      archive = "#{POLYML_DIR}/#{name}.gz"
      if_path_exists archive, base: :libexec do
        run "/usr/bin/gzip", args: ["-dkf", "{{libexec}}/#{archive}"]
      end
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tlapm --version")
    (testpath/"Smoke.tla").write <<~TLA
      ---- MODULE Smoke ----
      EXTENDS Naturals, TLAPS
      VARIABLE p
      THEOREM TwoPlusTwo == 2 + 2 = 4
      BY Z3
      THEOREM ThreePlusThree == 3 + 3 = 6
      BY Isa
      THEOREM AlwaysImpliesEventually == []p => <>p
      BY LS4
      ====
    TLA
    assert_match(/All [1-9]\d* obligations? proved\./, shell_output("#{bin}/tlapm --strict Smoke.tla 2>&1"))
  end
end
