class Supervisor < Formula
  include Language::Python::Virtualenv

  desc "Process Control System"
  homepage "http://supervisord.org/"
  url "https://files.pythonhosted.org/packages/ce/37/517989b05849dd6eaa76c148f24517544704895830a50289cbbf53c7efb9/supervisor-4.2.5.tar.gz"
  sha256 "34761bae1a23c58192281a5115fb07fbf22c9b0133c08166beffc70fed3ebc12"
  license "BSD-3-Clause-Modification"
  revision 1
  head "https://github.com/Supervisor/supervisor.git", branch: "master"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sequoia:  "451fc426f65e766105f5984229fd998477ebce5ff61e3905ed0de3e91e0cb5f3"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "ec664bd2e3bc60bd9a8514ac2a16da34a0a9efcebb8fe775b21698af40909444"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "ec664bd2e3bc60bd9a8514ac2a16da34a0a9efcebb8fe775b21698af40909444"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "ec664bd2e3bc60bd9a8514ac2a16da34a0a9efcebb8fe775b21698af40909444"
    sha256 cellar: :any_skip_relocation, sonoma:         "2eb8e7fba66707eda58ce2a41920c5a0281e64a376a0e1130018ae3ba32f3c9b"
    sha256 cellar: :any_skip_relocation, ventura:        "2eb8e7fba66707eda58ce2a41920c5a0281e64a376a0e1130018ae3ba32f3c9b"
    sha256 cellar: :any_skip_relocation, monterey:       "2eb8e7fba66707eda58ce2a41920c5a0281e64a376a0e1130018ae3ba32f3c9b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "78207f4fe866c1554ce1ffc5d574a74fb8ccc7cf30fd662917bcc6e76023457f"
  end

  depends_on "python@3.13"

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/27/b8/f21073fde99492b33ca357876430822e4800cdf522011f18041351dfa74b/setuptools-75.1.0.tar.gz"
    sha256 "d59a21b17a275fb872a9c3dae73963160ae079f1049ed956880cd7c09b120538"
  end

  def install
    inreplace buildpath/"supervisor/skel/sample.conf" do |s|
      s.gsub! %r{/tmp/supervisor\.sock}, var/"run/supervisor.sock"
      s.gsub! %r{/tmp/supervisord\.log}, var/"log/supervisord.log"
      s.gsub! %r{/tmp/supervisord\.pid}, var/"run/supervisord.pid"
      s.gsub!(/^;\[include\]$/, "[include]")
      s.gsub! %r{^;files = relative/directory/\*\.ini$}, "files = #{etc}/supervisor.d/*.ini"
    end

    virtualenv_install_with_resources

    etc.install buildpath/"supervisor/skel/sample.conf" => "supervisord.conf"
  end

  def post_install
    (var/"run").mkpath
    (var/"log").mkpath
    conf_warn = <<~EOS
      The default location for supervisor's config file is now:
        #{etc}/supervisord.conf
      Please move your config file to this location and restart supervisor.
    EOS
    old_conf = etc/"supervisord.ini"
    opoo conf_warn if old_conf.exist?
  end

  service do
    run [opt_bin/"supervisord", "-c", etc/"supervisord.conf", "--nodaemon"]
    keep_alive true
  end

  test do
    (testpath/"sd.ini").write <<~EOS
      [unix_http_server]
      file=supervisor.sock

      [supervisord]
      loglevel=debug

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

      [supervisorctl]
      serverurl=unix://supervisor.sock
    EOS

    begin
      pid = fork { exec bin/"supervisord", "--nodaemon", "-c", "sd.ini" }
      sleep 1
      output = shell_output("#{bin}/supervisorctl -c sd.ini version")
      assert_match version.to_s, output
    ensure
      Process.kill "TERM", pid
    end
  end
end
