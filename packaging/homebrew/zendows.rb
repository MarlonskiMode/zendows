cask "zendows" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "@URL@"
  name "Zendows"
  desc "Tiling window manager with stable logical windows"
  homepage "https://github.com/MarlonskiMode/zendows/"

  livecheck do
    url "https://example.invalid/zendows-updates/desktop/stable.json"
    strategy :json do |json|
      json.dig("release", "version")
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Zendows.app"
  binary "#{appdir}/Zendows.app/Contents/MacOS/zendows"

  uninstall quit: "com.marlonskimode.zendows"

  zap trash: [
    "~/.config/zendows",
    "~/Library/Application Support/Zendows",
    "~/Library/Caches/com.marlonskimode.zendows",
    "~/Library/HTTPStorages/com.marlonskimode.zendows",
    "~/Library/Preferences/com.marlonskimode.zendows.plist",
    "~/Library/Saved Application State/com.marlonskimode.zendows.savedState",
  ]
end
