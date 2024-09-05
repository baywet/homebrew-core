class Coin3d < Formula
  desc "Open Inventor 2.1 API implementation (Coin) with Python bindings (Pivy)"
  homepage "https://coin3d.github.io/"
  license all_of: ["BSD-3-Clause", "ISC"]

  stable do
    url "https://github.com/coin3d/coin/releases/download/v4.0.3/coin-4.0.3-src.zip"
    sha256 "b33cb6e2b7e93757239f852646e14c5f087a84e570dfe73afe5c65d5ac5e2d80"

    resource "soqt" do
      url "https://github.com/coin3d/soqt/releases/download/v1.6.2/soqt-1.6.2-src.tar.gz"
      sha256 "fb483b20015ab827ba46eb090bd7be5bc2f3d0349c2f947c3089af2b7003869c"
    end

    # We use the pre-release to support `pyside` and `python@3.12`.
    # This matches Arch Linux[^1] and Debian[^2] packages.
    #
    # [^1]: https://archlinux.org/packages/extra/x86_64/python-pivy/
    # [^2]: https://packages.debian.org/trixie/python3-pivy
    resource "pivy" do
      url "https://github.com/coin3d/pivy/archive/refs/tags/0.6.9.a0.tar.gz"
      sha256 "2c2da80ae216fe06394562f4a8fc081179d678f20bf6f8ec412cda470d7eeb91"
    end
  end

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any, arm64_sonoma:   "109634fdffabd73998545546b0608fb74e325744326e8d5e6e5a7911c0c47c47"
    sha256 cellar: :any, arm64_ventura:  "99d3003891e5b8b7264d74feb424acfaeab6b721d82c0e90a908b79536ff9f13"
    sha256 cellar: :any, arm64_monterey: "ce73bef75ed4334d2a880bebb4f96c729eeac891bd73ef6ca042fef7ed7c9509"
    sha256 cellar: :any, sonoma:         "9940156cce6b8569b81dfb790b958e2b9d9c370daa15888bdca668b0deb230d9"
    sha256 cellar: :any, ventura:        "2b85535a188812a6211ec7f4aa80962b6786a9ed7a9010a3384d5b4e1b09fed4"
    sha256 cellar: :any, monterey:       "e63ea57db53d46dcbf42ad69021b3c1a4363621ccae6a6995481cc0a70f88f68"
  end

  head do
    url "https://github.com/coin3d/coin.git", branch: "master"

    resource "soqt" do
      url "https://github.com/coin3d/soqt.git", branch: "master"
    end

    resource "pivy" do
      url "https://github.com/coin3d/pivy.git", branch: "master"
    end
  end

  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "swig" => :build
  depends_on "boost"
  depends_on "pyside"
  depends_on "python@3.12"
  depends_on "qt"

  on_linux do
    depends_on "mesa"
    depends_on "mesa-glu"
  end

  def python3
    "python3.12"
  end

  def install
    system "cmake", "-S", ".", "-B", "_build",
                    "-DCOIN_BUILD_MAC_FRAMEWORK=OFF",
                    "-DCOIN_BUILD_DOCUMENTATION=ON",
                    "-DCOIN_BUILD_TESTS=OFF",
                    *std_cmake_args(find_framework: "FIRST")
    system "cmake", "--build", "_build"
    system "cmake", "--install", "_build"

    resource("soqt").stage do
      system "cmake", "-S", ".", "-B", "_build",
                      "-DCMAKE_INSTALL_RPATH=#{rpath}",
                      "-DSOQT_BUILD_MAC_FRAMEWORK=OFF",
                      "-DSOQT_BUILD_DOCUMENTATION=OFF",
                      "-DSOQT_BUILD_TESTS=OFF",
                      *std_cmake_args(find_framework: "FIRST")
      system "cmake", "--build", "_build"
      system "cmake", "--install", "_build"
    end

    resource("pivy").stage do
      # Work around brew's Cellar directory structure
      cmakelists = ["CMakeLists.txt", "interfaces/CMakeLists.txt"]
      inreplace cmakelists, "${Python_SITEARCH}", prefix/Language::Python.site_packages(python3)

      system "cmake", "-S", ".", "-B", "_build",
                      "-DCMAKE_INSTALL_RPATH=#{lib}",
                      "-DPIVY_USE_QT6=ON",
                      "-DPython_EXECUTABLE=#{which(python3)}",
                      *std_cmake_args(find_framework: "FIRST")
      system "cmake", "--build", "_build"
      system "cmake", "--install", "_build"
    end
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <Inventor/SoDB.h>
      int main() {
        SoDB::init();
        SoDB::cleanup();
        return 0;
      }
    EOS

    opengl_flags = if OS.mac?
      ["-Wl,-framework,OpenGL"]
    else
      ["-L#{Formula["mesa"].opt_lib}", "-lGL"]
    end

    system ENV.cc, "test.cpp", "-L#{lib}", "-lCoin", *opengl_flags, "-o", "test"
    system "./test"

    # Set QT_QPA_PLATFORM to minimal to avoid error:
    # "This application failed to start because no Qt platform plugin could be initialized."
    ENV["QT_QPA_PLATFORM"] = "minimal" if OS.linux? && ENV["HOMEBREW_GITHUB_ACTIONS"]
    system python3, "-c", <<~EOS
      import shiboken6
      from pivy.sogui import SoGui
      assert SoGui.init("test") is not None
    EOS
  end
end
