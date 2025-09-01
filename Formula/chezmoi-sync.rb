# frozen_string_literal: true

class ChezmoiSync < Formula
  desc "Automated dotfiles synchronization for multiple machines using chezmoi"
  homepage "https://github.com/mishaal79/chezmoi-sync"
  url "https://github.com/mishaal79/chezmoi-sync/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "fc178c5fa03b15e634fd3623a98fb63ddc38dfce96d362b8e3242a08cf6242bb"
  license "MIT"
  head "https://github.com/mishaal79/chezmoi-sync.git", branch: "main"

  depends_on "chezmoi"
  depends_on "jq"
  depends_on :macos

  def install
    # Create directories
    (etc/"chezmoi-sync").mkpath
    (var/"log/chezmoi-sync").mkpath
    (var/"lib/chezmoi-sync").mkpath

    # Install scripts with path replacements
    scripts_to_install = %w[
      chezmoi-push.sh
      chezmoi-pull.sh
      chezmoi-sync-status.sh
      chezmoi-sync-dev-mode.sh
    ]

    scripts_to_install.each do |script|
      script_content = File.read("scripts/#{script}")
      
      # Replace hardcoded paths with Homebrew paths
      script_content.gsub!("${HOME}/code/private/chezmoi-sync/config/", "#{etc}/chezmoi-sync/")
      script_content.gsub!("${HOME}/Library/Logs/chezmoi", "#{var}/log/chezmoi-sync")
      script_content.gsub!("${HOME}/.config/chezmoi-sync/", "#{var}/lib/chezmoi-sync/")
      script_content.gsub!("CONFIG_FILE=\"${HOME}/code/private/chezmoi-sync/config/chezmoi-sync.conf\"", 
                          "CONFIG_FILE=\"#{etc}/chezmoi-sync/chezmoi-sync.conf\"")
      script_content.gsub!("LOG_DIR=\"${LOG_DIR:-$HOME/Library/Logs/chezmoi}\"", 
                          "LOG_DIR=\"${LOG_DIR:-#{var}/log/chezmoi-sync}\"")
      
      # Write modified script
      script_name = script.chomp(".sh")
      script_path = bin/"chezmoi-sync-#{script_name.sub('chezmoi-', '')}"
      script_path.write(script_content)
      script_path.chmod(0755)
    end

    # Create main chezmoi-sync command
    (bin/"chezmoi-sync").write <<~EOS
      #!/bin/bash
      
      COMMAND="${1:-status}"
      shift || true
      
      case "$COMMAND" in
        status|st)
          exec "#{bin}/chezmoi-sync-status" "$@"
          ;;
        push)
          exec "#{bin}/chezmoi-sync-push" "$@"
          ;;
        pull)
          exec "#{bin}/chezmoi-sync-pull" "$@"
          ;;
        dev-mode|dev)
          exec "#{bin}/chezmoi-sync-dev-mode" "$@"
          ;;
        restart)
          brew services restart chezmoi-sync
          brew services restart chezmoi-sync-pull
          ;;
        stop)
          brew services stop chezmoi-sync
          brew services stop chezmoi-sync-pull
          ;;
        start)
          brew services start chezmoi-sync
          brew services start chezmoi-sync-pull
          ;;
        *)
          echo "Usage: chezmoi-sync {status|push|pull|dev-mode|restart|stop|start}"
          exit 1
          ;;
      esac
    EOS
    chmod 0755, bin/"chezmoi-sync"

    # Install configuration file
    config_content = File.read("config/chezmoi-sync.conf")
    config_content.gsub!("LOG_DIR=\"${HOME}/Library/Logs/chezmoi\"", 
                        "LOG_DIR=\"#{var}/log/chezmoi-sync\"")
    (etc/"chezmoi-sync/chezmoi-sync.conf").write(config_content)
  end

  def post_install
    # Check for existing installation and migrate if necessary
    legacy_machine_id = "#{ENV["HOME"]}/.config/chezmoi-sync/machine-id"
    new_machine_id = "#{var}/lib/chezmoi-sync/machine-id"
    
    if File.exist?(legacy_machine_id) && !File.exist?(new_machine_id)
      ohai "Migrating existing machine ID from manual installation"
      FileUtils.cp(legacy_machine_id, new_machine_id)
    end

    # Create initial machine ID if not exists
    unless File.exist?(new_machine_id)
      require "socket"
      machine_id = if OS.mac?
        `scutil --get LocalHostName 2>/dev/null`.strip.presence || Socket.gethostname.split(".").first
      else
        Socket.gethostname.split(".").first
      end
      
      machine_id = machine_id.downcase.gsub(/[^a-z0-9-]/, "-")
      File.write(new_machine_id, machine_id)
      ohai "Created machine ID: #{machine_id}"
    end

    # Clean up old LaunchAgents if they exist
    legacy_agents = %w[
      com.chezmoi.autopush.plist
      com.chezmoi.autopull.plist
    ]
    
    legacy_agents.each do |agent|
      agent_path = "#{ENV["HOME"]}/Library/LaunchAgents/#{agent}"
      if File.exist?(agent_path)
        ohai "Found legacy LaunchAgent: #{agent}"
        system("launchctl", "unload", agent_path, err: :null)
        FileUtils.rm_f(agent_path)
      end
    end
  end

  service do
    name macos: "com.chezmoi.sync.push"
    
    # Push service with WatchPaths
    run [opt_bin/"chezmoi-sync-push"]
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin",
                          HOMEBREW_PREFIX: HOMEBREW_PREFIX.to_s
    log_path var/"log/chezmoi-sync/push.log"
    error_log_path var/"log/chezmoi-sync/push.error.log"
    
    # WatchPaths for detecting changes
    if OS.mac?
      watch_paths ["#{ENV["HOME"]}/.local/share/chezmoi"]
    end
    
    # Throttle to prevent excessive runs
    restart_delay 5
  end

  # Define second service for pull operations
  service "chezmoi-sync-pull" do
    name macos: "com.chezmoi.sync.pull"
    
    run [opt_bin/"chezmoi-sync-pull"]
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin",
                          HOMEBREW_PREFIX: HOMEBREW_PREFIX.to_s
    log_path var/"log/chezmoi-sync/pull.log"
    error_log_path var/"log/chezmoi-sync/pull.error.log"
    
    # Run every 5 minutes
    interval 300
  end

  def caveats
    <<~EOS
      Chezmoi-sync has been installed!

      To get started:
        1. Start the services:
           brew services start chezmoi-sync
           brew services start chezmoi-sync-pull

        2. Check status:
           chezmoi-sync status

        3. Manage services:
           chezmoi-sync start    # Start both services
           chezmoi-sync stop     # Stop both services
           chezmoi-sync restart  # Restart both services

      Development mode:
        chezmoi-sync dev-mode on   # Disable auto-sync
        chezmoi-sync dev-mode off  # Re-enable auto-sync

      Logs are stored at:
        #{var}/log/chezmoi-sync/

      Configuration file:
        #{etc}/chezmoi-sync/chezmoi-sync.conf

      Machine ID stored at:
        #{var}/lib/chezmoi-sync/machine-id
    EOS
  end

  test do
    # Test that the main command exists and runs
    assert_match "Chezmoi Sync System Status", shell_output("#{bin}/chezmoi-sync status 2>&1")
    
    # Test that configuration file exists
    assert_predicate etc/"chezmoi-sync/chezmoi-sync.conf", :exist?
    
    # Test that log directory was created
    assert_predicate var/"log/chezmoi-sync", :directory?
    
    # Test machine ID generation
    assert_predicate var/"lib/chezmoi-sync/machine-id", :exist?
  end
end