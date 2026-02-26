class ClaudeAgent < Formula
  desc "Mac agent daemon for Claude Orchestrator — control Claude from your iPhone"
  homepage "https://github.com/tergeoo/Claude-Orchestrator"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/tergeoo/Claude-Orchestrator/releases/download/v1.0.0/claude-agent-darwin-arm64"
      sha256 "c42e22cac97269873888ab01ebf9363b29a24d86f3b3c2eba3120853fe40341c"
      version "1.0.0"
    end
    on_intel do
      url "https://github.com/tergeoo/Claude-Orchestrator/releases/download/v1.0.0/claude-agent-darwin-amd64"
      sha256 "14a212ce1a5c5b5acd665bd6a65bf0493b27d0ccd5f0839866503b3198bee089"
      version "1.0.0"
    end
  end

  def install
    binary = Dir["claude-agent-darwin-*"].first
    bin.install binary => "claude-agent"
  end

  def caveats
    <<~EOS
      To run the agent:
        claude-agent --relay wss://YOUR_RELAY --secret YOUR_SECRET

      Or create a config file first:
        claude-agent --init
        # Edit ~/.config/claude-agent/config.yaml
        claude-agent

      To run as a background service (auto-start on login):
        brew services start claude-agent
        # Make sure ~/.config/claude-agent/config.yaml has relay_url and secret set
    EOS
  end

  service do
    run [opt_bin/"claude-agent", "--config",
         "#{Dir.home}/.config/claude-agent/config.yaml"]
    keep_alive true
    log_path "/tmp/claude-agent.log"
    error_log_path "/tmp/claude-agent.log"
    working_dir Dir.home
  end

  test do
    output = shell_output("#{bin}/claude-agent --help 2>&1", 2)
    assert_match "relay", output
  end
end
