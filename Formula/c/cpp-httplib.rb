class CppHttplib < Formula
  desc "C++ header-only HTTP/HTTPS server and client library"
  homepage "https://github.com/yhirose/cpp-httplib"
  url "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.17.2.tar.gz"
  sha256 "c1234649a9198d04c42178bc434b51032b75cf295005bcfd040410267c1a75f1"
  license "MIT"

  bottle do
    sha256 cellar: :any_skip_relocation, all: "6148e9da7898b06986344fd2f20c898574a030288bd28d2bde12d69d67475e89"
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build

  fails_with :clang do
    build 1300
    cause <<~EOS
      include/httplib.h:5278:19: error: no viable overloaded '='
      request.matches = {};
      ~~~~~~~~~~~~~~~ ^ ~~
    EOS
  end

  def install
    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"server.cpp").write <<~CPP
      #include <httplib.h>
      using namespace httplib;

      int main(void) {
        Server svr;

        svr.Get("/hi", [](const Request &, Response &res) {
          res.set_content("Hello World!", "text/plain");
        });

        svr.listen("0.0.0.0", 8080);
      }
    CPP
    (testpath/"client.cpp").write <<~CPP
      #include <httplib.h>
      #include <iostream>
      using namespace httplib;
      using namespace std;

      int main(void) {
        Client cli("localhost", 8080);
        if (auto res = cli.Get("/hi")) {
          cout << res->status << endl;
          cout << res->get_header_value("Content-Type") << endl;
          cout << res->body << endl;
          return 0;
        } else {
          return 1;
        }
      }
    CPP
    system ENV.cxx, "server.cpp", "-I#{include}", "-lpthread", "-std=c++17", "-o", "server"
    system ENV.cxx, "client.cpp", "-I#{include}", "-lpthread", "-std=c++17", "-o", "client"

    fork do
      exec "./server"
    end
    sleep 3
    assert_match "Hello World!", shell_output("./client")
  end
end
