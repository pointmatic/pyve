class Pyve < Formula
  desc "Single, easy entry point for all your virtual environments"
  homepage "https://pointmatic.github.io/pyve"
  url "https://github.com/pointmatic/pyve/archive/refs/tags/v3.0.3.tar.gz"
  sha256 "de6a7b820c28150065046a1448a6403d5a27f924ac7ca2560fdd021940214fcc"
  license "Apache-2.0"

  # tomllib (used by pyve) requires Python >= 3.11. This brew Python only
  # needs to be a viable bootstrap interpreter; the toolchain venv itself is
  # still version-keyed to DEFAULT_PYTHON_VERSION via _self_install_toolchain_python.
  depends_on "python@3.12"

  def install
    # Install pyve.sh and lib/ into libexec so SCRIPT_DIR resolution
    # finds lib/ relative to the actual script location.
    libexec.install "pyve.sh"
    libexec.install "lib"
    chmod 0755, libexec/"pyve.sh"

    # Create a wrapper script in bin/ that execs the real pyve.sh
    (bin/"pyve").write <<~SH
      #!/bin/bash
      exec "#{libexec}/pyve.sh" "$@"
    SH
    chmod 0755, bin/"pyve"
  end

  # `pyve self provision` (run at install/upgrade time, above) creates files
  # OUTSIDE Homebrew's prefix that `brew uninstall pyve` cannot clean up:
  #   - the toolchain Python venv at ~/.local/share/pyve/toolchain/
  #   - the project-guide shim at ~/.local/bin/project-guide
  # Homebrew has no supported post_uninstall hook for paths outside its
  # prefix, so these are orphaned on `brew uninstall`. Point users at the
  # brew-safe teardown so they can remove them deliberately.
  def caveats
    <<~EOS
      Pyve hosts a toolchain Python venv with the Project-Guide CLI outside
      Homebrew's prefix:
        ~/.local/share/pyve/toolchain/   (toolchain Python + hosted tools)
        ~/.local/bin/project-guide       (Project-Guide shim)

      First-time setup — install the Pyve toolchain + the Project-Guide CLI:
        pyve self provision

      Uninstalling Pyve alone leaves Project-Guide working in your projects
      (via the shim above); `brew uninstall pyve` CANNOT remove these.
      For a full uninstall of Pyve and the toolchain, run in this order:
        pyve self unprovision --all
        brew uninstall pyve

      You can reprovision the toolchain any time while Pyve is installed,
      and it will upgrade the hosted Project-Guide:
        pyve self provision        # always pip-installs --upgrade
      (`pyve update` refreshes a project's scaffolding from the version of
      Project-Guide already hosted in the toolchain; it does NOT upgrade it.)

      For general info about Project-Guide, see
      https://pointmatic.github.io/project-guide/
    EOS
  end

  test do
    assert_match "pyve version #{version}", shell_output("#{bin}/pyve --version")

    # v3 end-to-end smoke: initialize a venv-backed project and confirm the
    # v3 manifest (pyve.toml) and environment (.venv) are materialized — this
    # exercises the real v3 command surface, not a retired v2 command. The
    # sandbox has no version manager, so expose the formula's Python as bare
    # `python` (pyve invokes `python` directly), and suppress every prompt and
    # all network access (project-guide hosting).
    (testpath/"shims").mkpath
    (testpath/"shims/python").make_symlink(Formula["python@3.12"].opt_bin/"python3.12")
    ENV.prepend_path "PATH", testpath/"shims"
    ENV["PYVE_INIT_NONINTERACTIVE"] = "1"
    ENV["PYVE_NO_PROJECT_GUIDE"] = "1"
    ENV["PYVE_NO_PROJECT_GUIDE_COMPLETION"] = "1"

    system bin/"pyve", "init", "--backend", "venv"
    assert_predicate testpath/"pyve.toml", :exist?
    assert_predicate testpath/".venv/bin/python", :exist?
  end
end
