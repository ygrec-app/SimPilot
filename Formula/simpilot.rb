class Simpilot < Formula
  desc "iOS Simulator automation framework — Playwright for iOS"
  homepage "https://github.com/ygrec-app/SimPilot"
  license "MIT"
  head "https://github.com/ygrec-app/SimPilot.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build",
           "-c", "release",
           "--disable-sandbox",
           "--arch", "arm64",
           "--arch", "x86_64"
    bin.install ".build/apple/Products/Release/simpilot"
  end

  test do
    assert_match "SimPilot", shell_output("#{bin}/simpilot version")
  end
end
