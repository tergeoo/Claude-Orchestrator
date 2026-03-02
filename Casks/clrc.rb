cask "clrc" do
  arch arm: "arm64", intel: "amd64"

  version "1.2.0"
  sha256 arm:   "5da0a1d04e27b1ad2946946e41da3299c6ba3c4e5abca8d1651c816c1b104cf3",
         intel: "33440495248b761853e70f5db814b11a0beb35ddf43da83aecce7685d1e4dbad"

  url "https://github.com/tergeoo/clrc/releases/download/v#{version}/clrc-darwin-#{arch}"
  name "clrc"
  desc "Claude Remote Control — use Claude CLI on your Mac from your iPhone"
  homepage "https://github.com/tergeoo/clrc"

  binary "clrc-darwin-#{arch}", target: "clrc"

  caveats <<~EOS
    Configure clrc before starting:
      $EDITOR #{Dir.home}/.config/clrc/.env

    Required fields: RELAY_URL and AGENT_SECRET.

    Start the daemon:
      clrc start        # start once in background
      clrc stop         # stop
      clrc status       # check status
      clrc logs         # tail logs
  EOS
end
